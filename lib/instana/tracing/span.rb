module Instana
  class Span
    REGISTERED_SPANS = [ :actioncontroller, :actionview, :activerecord, :excon,
                         :memcache, :'net-http', :rack, :render, :'rpc-client',
                         :'rpc-server', :'sidekiq-client', :'sidekiq-worker',
                         :redis, :'resque-client', :'resque-worker' ].freeze
    ENTRY_SPANS = [ :rack, :'resque-worker', :'rpc-server', :'sidekiq-worker' ].freeze
    EXIT_SPANS = [ :activerecord, :excon, :'net-http', :'resque-client',
                   :'rpc-client', :'sidekiq-client', :redis ].freeze
    HTTP_SPANS = [ :rack, :excon, :'net-http' ].freeze

    attr_accessor :parent
    attr_accessor :baggage
    attr_accessor :is_root

    def initialize(name, trace_id, parent_id: nil, start_time: ::Instana::Util.now_in_ms)
      @data = {}
      @data[:t] = trace_id                    # Trace ID
      @data[:s] = ::Instana::Util.generate_id # Span ID
      @data[:p] = parent_id if parent_id      # Parent ID
      @data[:ta] = :ruby                      # Agent
      @data[:data] = {}

      # Mark this span as root if the trace_id is the same as span_id
      @is_root = (@data[:s] == @data[:t])

      # Entity Source
      @data[:f] = { :e => ::Instana.agent.report_pid,
                    :h => ::Instana.agent.agent_uuid }
      # Start time
      if start_time.is_a?(Time)
        @data[:ts] = ::Instana::Util.time_to_ms(start_time)
      else
        @data[:ts] = start_time
      end

      @baggage = {}

      if ::Instana.config[:collect_backtraces]
        # For entry spans, add a backtrace fingerprint
        add_stack(limit: 2) if ENTRY_SPANS.include?(name)

        # Attach a backtrace to all exit spans
        add_stack if EXIT_SPANS.include?(name)
      end

      # Check for custom tracing
      if REGISTERED_SPANS.include?(name.to_sym)
        @data[:n] = name.to_sym
      else
        configure_custom(name)
      end
    end

    # Adds a backtrace to this span
    #
    # @param limit [Integer] Limit the backtrace to the top <limit> frames
    #
    def add_stack(limit: nil, stack: Kernel.caller)
      frame_count = 0
      @data[:stack] = []

      stack.each do |i|
        # If the stack has the full instana gem version in it's path
        # then don't include that frame. Also don't exclude the Rack module.
        if !i.match(/instana\/instrumentation\/rack.rb/).nil? ||
          (i.match(::Instana::VERSION_FULL).nil? && i.match('lib/instana/').nil?)

          break if limit && frame_count >= limit

          x = i.split(':')

          @data[:stack] << {
            :c => x[0],
            :n => x[1],
            :m => x[2]
          }
         frame_count = frame_count + 1 if limit
        end
      end
    end

    # Log an error into the span
    #
    # @param e [Exception] The exception to be logged
    #
    def add_error(e)
      @data[:error] = true

      if @data.key?(:ec)
        @data[:ec] = @data[:ec] + 1
      else
        @data[:ec] = 1
      end

      # If a valid exception has been passed in, log the information about it
      # In case of just logging an error for things such as HTTP client 5xx
      # responses, an exception/backtrace may not exist.
      if e
        if e.backtrace.is_a?(Array)
          add_stack(stack: e.backtrace)
        end

        if HTTP_SPANS.include?(@data[:n])
          set_tags(:http => { :error => "#{e.class}: #{e.message}" })
        else
          log(:error, Time.now, { :message => e.message, :parameters => e.class.to_s })
        end
        e.instance_variable_set(:@instana_logged, true)
      end
      self
    end


    # Configure this span to be a custom span per the
    # SDK generic span type.
    #
    # Default to an intermediate kind span.  Can be overridden by
    # setting a span.kind tag.
    #
    # @param name [String] name of the span
    # @param kvs [Hash] list of key values to be reported in the span
    #
    def configure_custom(name)
      @data[:n] = :sdk
      @data[:k] = :intermediate
      @data[:data] = { :sdk => { :name => name.to_sym, :type => :intermediate } }
      @data[:data][:sdk][:custom] = { :tags => {}, :logs => {} }
      self
    end

    # Closes out the span.  This difference between this and
    # the finish method tells us how the tracing is being
    # performed (with OpenTracing or Instana default)
    #
    # @param end_time [Time] custom end time, if not now
    # @return [Span]
    #
    def close(end_time = ::Instana::Util.now_in_ms)
      if end_time.is_a?(Time)
        end_time = ::Instana::Util.time_to_ms(end_time)
      end

      @data[:d] = end_time - @data[:ts]
      self
    end

    #############################################################
    # Accessors
    #############################################################

    # Retrieve the context of this span.
    #
    # @return [Instana::SpanContext]
    #
    def context
      @context ||= ::Instana::SpanContext.new(@data[:t], @data[:s], @baggage)
    end

    # Retrieve the ID for this span
    #
    # @return [Integer] the span ID
    def id
      @data[:s]
    end

    # Retrieve the Trace ID for this span
    #
    # @return [Integer] the Trace ID
    def trace_id
      @data[:t]
    end

    # Retrieve the parent ID of this span
    #
    # @return [Integer] parent span ID
    def parent_id
      @data[:p]
    end

    # Set the parent ID of this span
    #
    # @return [Integer] parent span ID
    def parent_id=(id)
      @data[:p] = id
    end

    # Get the name (operation) of this Span
    #
    # @return [String] or [Symbol] representing the span name
    def name
      if custom?
        @data[:data][:sdk][:name]
      else
        @data[:n]
      end
    end

    # Set the name (operation) for this Span
    #
    # @params name [String] or [Symbol]
    #
    def name=(n)
      if custom?
        @data[:data][:sdk][:name] = n
      else
        @data[:n] = n
      end
    end

    # Get the duration value for this Span
    #
    # @return [Integer] the duration in milliseconds
    def duration
      @data[:d]
    end

    # Hash accessor to the internal @data hash
    #
    def [](key)
      @data[key.to_sym]
    end

    # Hash setter to the internal @data hash
    #
    def []=(key, value)
      @data[key.to_sym] = value
    end

    # Hash key query to the internal @data hash
    #
    def key?(k)
      @data.key?(k.to_sym)
    end

    # Get the raw @data hash that summarizes this span
    #
    def raw
      @data
    end

    # Indicates whether this span is a custom or registered Span
    def custom?
      @data[:n] == :sdk
    end

    def inspect
      @data.inspect
    end

    #############################################################
    # OpenTracing Compatibility Methods
    #############################################################

    # Set the name of the operation
    # Spec: OpenTracing API
    #
    # @params name [String] or [Symbol]
    #
    def operation_name=(name)
      @data[:n] = name
    end

    # Set a tag value on this span
    # Spec: OpenTracing API
    #
    # @param key [String] the key of the tag
    # @param value [String, Numeric, Boolean] the value of the tag. If it's not
    # a String, Numeric, or Boolean it will be encoded with to_s
    #
    def set_tag(key, value)
      if custom?
        @data[:data][:sdk][:custom] ||= {}
        @data[:data][:sdk][:custom][:tags] ||= {}
        @data[:data][:sdk][:custom][:tags][key] = value

        if key.to_sym == :'span.kind'
          case value.to_sym
          when :server, :consumer
            @data[:data][:sdk][:type] = @data[:k] = :entry
          when :client, :producer
            @data[:data][:sdk][:type] = @data[:k] = :exit
          else
            @data[:data][:sdk][:type] = @data[:k] = :intermediate
          end
        end
      else
        if !@data[:data].key?(key)
          @data[:data][key] = value
        elsif value.is_a?(Hash) && self[:data][key].is_a?(Hash)
          @data[:data][key].merge!(value)
        else
          @data[:data][key] = value
        end
      end
      self
    end

    # Helper method to add multiple tags to this span
    #
    # @params tags [Hash]
    # @return [Span]
    #
    def set_tags(tags)
      return unless tags.is_a?(Hash)
      tags.each do |k,v|
        set_tag(k, v)
      end
      self
    end

    # Set a baggage item on the span
    # Spec: OpenTracing API
    #
    # @param key [String] the key of the baggage item
    # @param value [String] the value of the baggage item
    def set_baggage_item(key, value)
      @baggage ||= {}
      @baggage[key] = value

      # Init/Update the SpanContext item
      if @context
        @context.baggage = @baggage
      else
        @context ||= ::Instana::SpanContext.new(@data[:t], @data[:s], @baggage)
      end
      self
    end

    # Get a baggage item
    # Spec: OpenTracing API
    #
    # @param key [String] the key of the baggage item
    # @return Value of the baggage item
    #
    def get_baggage_item(key)
      @baggage[key]
    end

    # Retrieve the hash of tags for this span
    #
    def tags(key = nil)
      if custom?
        tags = @data[:data][:sdk][:custom][:tags]
      else
        tags = @data[:data][key]
      end
      key ? tags[key] : tags
    end

    # Add a log entry to this span
    # Spec: OpenTracing API
    #
    # @param event [String] event name for the log
    # @param timestamp [Time] time of the log
    # @param fields [Hash] Additional information to log
    #
    def log(event = nil, timestamp = Time.now, **fields)
      ts = ::Instana::Util.time_to_ms(timestamp).to_s
      if custom?
        @data[:data][:sdk][:custom][:logs][ts] = fields
        @data[:data][:sdk][:custom][:logs][ts][:event] = event
      else
        set_tags(:log => fields)
      end
    rescue StandardError => e
      Instana.logger.debug "#{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}"
    end

    # Finish the {Span}
    # Spec: OpenTracing API
    #
    # @param end_time [Time] custom end time, if not now
    #
    def finish(end_time = ::Instana::Util.now_in_ms)
      if ::Instana.tracer.current_span.id != id
        ::Instana.logger.debug "Closing a span that isn't active. This will result in a broken trace: #{self.inspect}"
      end

      if @is_root
        # This is the root span for the trace.  Call log_end to close
        # out and queue the trace
        ::Instana.tracer.log_end(name, {}, end_time)
      else
        ::Instana.tracer.current_trace.end_span({}, end_time)
      end
      self
    end
  end
end
