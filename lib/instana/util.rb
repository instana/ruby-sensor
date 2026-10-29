# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2016

module Instana
  module Util # rubocop:disable Metrics/ModuleLength
    class << self
      ID_RANGE = -2**63..2**63-1
      # Retrieves and returns the source code for any ruby
      # files requested by the UI via the host agent
      #
      # @param file [String] The fully qualified path to a file
      #
      def get_rb_source(file)
        if (file =~ /.rb$/).nil?
          { :error => "Only Ruby source files are allowed. (*.rb)" }
        else
          { :data => File.read(file) }
        end
      rescue => e
        return { :error => e.inspect }
      end

      # Method to collect up process info for snapshots.  This
      # is generally used once per process.
      #
      # :nocov:
      def take_snapshot
        data = {}

        data[:sensorVersion] = ::Instana::VERSION.dup
        data[:ruby_version] = RUBY_VERSION.dup
        data[:rpl] = RUBY_PATCHLEVEL if defined?(RUBY_PATCHLEVEL)

        # Framework Detection
        if defined?(::RailsLts::VERSION)
          data[:framework] = "Rails on Rails LTS-#{::RailsLts::VERSION}".dup

        elsif defined?(::Rails.version)
          data[:framework] = "Ruby on Rails #{::Rails.version}".dup

        elsif defined?(::Grape::VERSION)
          data[:framework] = "Grape #{::Grape::VERSION}".dup

        elsif defined?(::Padrino::VERSION)
          data[:framework] = "Padrino #{::Padrino::VERSION}".dup

        elsif defined?(::Sinatra::VERSION)
          data[:framework] = "Sinatra #{::Sinatra::VERSION}".dup
        end

        # Report Bundle
        if defined?(::Gem) && Gem.respond_to?(:loaded_specs)
          data[:versions] = {}

          Gem.loaded_specs.each do |k, v|
            data[:versions][k.dup] = v.version.to_s.dup
          end
        end

        data
      rescue => e
        ::Instana.logger.debug { "#{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}" }
        ::Instana.logger.debug { e.backtrace.join("\r\n") }
        return data
      end
      # :nocov:

      # Best effort to determine a name for the instrumented application
      # on the dashboard.
      #
      # :nocov:
      def get_app_name
        if ENV.key?('INSTANA_SERVICE_NAME')
          return ENV['INSTANA_SERVICE_NAME']
        end

        if defined?(::Resque)
          # Just because Resque is defined doesn't mean this is a resque process necessarily
          # Check arguments for a match
          if ($0 =~ /resque-#{Resque::Version}/)
            return "Resque Worker"
          elsif ($0 =~ /resque-pool-master/)
            return "Resque Pool Master"
          elsif ($0 =~ /resque-scheduler/)
            return "Resque Scheduler"
          end
        end

        rails_module = if defined?(::RailsLts)
                         then ::RailsLts
                       elsif defined?(::Rails)
                         then ::Rails
                       end

        if rails_module &&
           rails_module.respond_to?(:application_name) &&
           rails_module.instance_variables.include?(:@application) &&
           rails_module.application
          return rails_module.application_name
        end

        if $0.to_s.empty?
          return "Ruby"
        end

        exe = File.basename($0)
        if exe == "rake"
          return "Rake"
        end

        return exe
      rescue Exception => e
        Instana.logger.info "#{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}"
        Instana.logger.debug { e.backtrace.join("\r\n") }
        return "Ruby"
      end
      # :nocov:

      # Get the current time in milliseconds from the epoch
      #
      # @return [Integer] the current time in milliseconds
      #
      def now_in_ms
        Process.clock_gettime(Process::CLOCK_REALTIME, :millisecond)
      end
      # Prior method name support.  To be deprecated when appropriate.
      alias ts_now now_in_ms

      # Convert a Time value to milliseconds
      #
      # @param time [Time]
      #
      def time_to_ms(time)
        (time.to_f * 1000).floor
      end

      # Generate a random 64bit/128bit ID
      #
      # @param size [Integer] Number of 64 bit integers used to generate the id
      #
      # @return [String] a random 64bit/128bit hex encoded string
      #
      def generate_id(size = 1)
        Array.new(size) { rand(ID_RANGE) }
          .pack('q>*')
          .unpack('H*')
          .first
      end

      # Convert an ID to a value appropriate to pass in a header.
      #
      # @param id [String] the id to be converted
      #
      # @return [String]
      #
      def id_to_header(id)
        return '' unless id.is_a?(String)
        # Only send 64bit IDs downstream for now
        id.length == 32 ? id[16..-1] : id
      end

      # Convert a received header value into a valid ID
      #
      # @param header_id [String] the header value to be converted
      #
      # @return [String]
      #
      def header_to_id(given)
        return '' unless given.is_a?(String)
        return '' unless given.match(/\A[a-z\d]{16,32}\z/i)
        given
      end

      # Parse W3C +traceparent+ / +tracestate+ values using the OpenTelemetry
      # trace-context propagator.
      #
      # When the tracestate carries an Instana entry (+in=<trace>;<span>+) it
      # takes precedence over the ids in the traceparent.
      #
      # @param traceparent [String] the traceparent header value
      # @param tracestate [String, nil] the tracestate header value
      #
      # @return [Hash, nil] +nil+ when the traceparent is missing or invalid,
      #   otherwise a hash with:
      #   - +:trace_id+, +:span_id+, +:level+ for continuing the trace
      #   - +:external_trace_id+, +:external_trace_flags+, +:external_state+
      #     for re-emitting the W3C context downstream
      #
      def parse_w3c_trace_context(traceparent, tracestate = nil)
        return nil unless traceparent.is_a?(String)

        carrier = { 'traceparent' => traceparent, 'tracestate' => tracestate.is_a?(String) ? tracestate : nil }
        extracted = OpenTelemetry::Trace::Propagation::TraceContext.text_map_propagator.extract(
          carrier, context: OpenTelemetry::Context.empty
        )
        span_context = OpenTelemetry::Trace.current_span(extracted).context
        return nil unless span_context.valid?

        sampled = span_context.trace_flags.sampled?
        instana_state = span_context.tracestate.value('in')&.match(/\A(?<trace>[0-9a-f]+);(?<span>[0-9a-f]+)\z/)

        {
          trace_id: header_to_id(instana_state ? instana_state[:trace] : span_context.hex_trace_id[16..]),
          span_id: header_to_id(instana_state ? instana_state[:span] : span_context.hex_span_id),
          level: sampled ? 1 : 0,
          external_trace_id: span_context.hex_trace_id,
          external_trace_flags: sampled ? '01' : '00',
          external_state: tracestate
        }
      end

      def timeout_timestamp
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end

      def maybe_timeout(timeout, start_time)
        return nil if timeout.nil?

        timeout -= (timeout_timestamp - start_time)
        timeout.positive? ? timeout : 0
      end

      def extra_header_tags(req_res_headers)
        return {} if req_res_headers.nil?
        return nil unless ::Instana.agent.extra_headers

        headers = {}

        ::Instana.agent.extra_headers.each do |custom_header|
          headers[custom_header.to_sym] = req_res_headers[custom_header] if req_res_headers.key?(custom_header)
        end

        headers
      end

      # Return true if an HTTP exit span with +status_code+ should be marked as errored.
      #
      # Rules (in priority order):
      # 1. status >= 500  → always an error.
      # 2. 400 <= status <= 499 and +config[:http_exit_classify_as_errors]+ is non-empty
      #    → error only if +status_code+ is in that list.
      # 3. 400 <= status <= 499 and +config[:http_exit_classify_all_4xx_as_errors]+ is true
      #    → error for every 4xx code.
      # 4. Otherwise → not an error.
      #
      # Entry (server/rack) spans must never be passed here; this helper is for exit spans only.
      def should_mark_http_exit_as_error?(status_code)
        return true if status_code >= 500

        if (400..499).cover?(status_code)
          codes = ::Instana.config[:http_exit_classify_as_errors]
          return codes.include?(status_code) if codes&.any?

          return ::Instana.config[:http_exit_classify_all_4xx_as_errors]
        end

        false
      end

      # Return the HTTP reason phrase for a numeric status code, or nil if unknown.
      # Uses Ruby stdlib Net::HTTPResponse::CODE_TO_OBJ to derive the phrase from
      # the response class name (e.g. Net::HTTPUnauthorized → "Unauthorized").
      def http_reason_phrase(status_code)
        require 'net/http'
        klass = Net::HTTPResponse::CODE_TO_OBJ[status_code.to_s]
        return nil unless klass

        klass.name.sub('Net::HTTP', '').gsub(/([A-Z])/, ' \1').strip
      end

      # Build the W3C trace-context message attributes for an AWS message
      # (SQS or SNS).  Returns a hash suitable for merging into
      # +params[:message_attributes]+.
      #
      # @param span_context [Instana::SpanContext]
      # @return [Hash]
      #
      def aws_message_attributes_w3c(span_context)
        {
          'traceparent' => { data_type: 'String', string_value: span_context.trace_parent_header },
          'tracestate' => { data_type: 'String', string_value: span_context.trace_state_header }
        }
      end

      # Build the Instana proprietary message attributes for an AWS message
      # (SQS or SNS).  Returns a hash suitable for merging into
      # +params[:message_attributes]+.
      #
      # @param span_context [Instana::SpanContext]
      # @return [Hash]
      #
      def aws_message_attributes_instana(span_context)
        {
          'X_INSTANA_T' => { data_type: 'String', string_value: span_context.trace_id },
          'X_INSTANA_S' => { data_type: 'String', string_value: span_context.span_id },
          'X_INSTANA_L' => { data_type: 'String', string_value: span_context.level.to_s }
        }
      end
    end
  end
end
