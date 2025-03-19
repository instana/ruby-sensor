# (c) Copyright IBM Corp. 2025

require 'opentelemetry'
require 'instana/trace/span_kind'

module Instana
  class Span < OpenTelemetry::Trace::Span
    include SpanKind

    attr_accessor :parent, :baggage, :is_root, :context

    def initialize(name, parent_ctx: nil, start_time: ::Instana::Util.now_in_ms) # rubocop:disable Lint/MissingSuper
      @data = {}
      @ended = false
      if parent_ctx.is_a?(::Instana::Span)
        @parent = parent_ctx
        parent_ctx = parent_ctx.context
      end

      if parent_ctx.is_a?(::Instana::SpanContext)
        @is_root = false

        # If we have a parent trace, link to it
        if parent_ctx.trace_id
          @data[:t] = parent_ctx.trace_id       # Trace ID
          @data[:p] = parent_ctx.span_id        # Parent ID
        else
          @data[:t] = ::Instana::Trace.generate_trace_id
        end

        @data[:s] = ::Instana::Trace.generate_span_id # Span ID

        @baggage = parent_ctx.baggage.dup
        @level = parent_ctx.level
      else
        # No parent specified so we're starting a new Trace - this will be the root span
        @is_root = true
        @level = 1

        id = ::Instana::Trace.generate_span_id
        @data[:t] = id                    # Trace ID
        @data[:s] = id                    # Span ID
      end

      @data[:data] = {}

      if ENV.key?('INSTANA_SERVICE_NAME')
        @data[:data][:service] = ENV['INSTANA_SERVICE_NAME']
      end

      # Entity Source
      @data[:f] = ::Instana.agent.source
      # Start time
      @data[:ts] = if start_time.is_a?(Time)
                     ::Instana::Util.time_to_ms(start_time)
                   else
                     start_time
                   end

      # Check for custom tracing
      if REGISTERED_SPANS.include?(name.to_sym)
        @data[:n] = name.to_sym
      else
        configure_custom(name)
      end

      ::Instana.processor.on_start(self)

      # Attach a backtrace to all exit spans
      add_stack if ::Instana.config[:collect_backtraces] && exit_span?
    end

    # Adds a backtrace to this span
    #
    # @param limit [Integer] Limit the backtrace to the top <limit> frames
    #
    def add_stack(limit: 30, stack: Kernel.caller)
      cleaner = ::Instana.config[:backtrace_cleaner]
      stack = cleaner.call(stack) if cleaner

      @data[:stack] = stack
                      .map do |call|
        file, line, *method = call.split(':')

        {
          c: file,
          n: line,
          m: method.join(' ')
        }
      end.take(limit > 40 ? 40 : limit)
    end

    # Log an error into the span
    #
    # @param e [Exception] The exception to be logged
    #
    def record_exception(error)
      @data[:error] = true

      @data[:ec] = if @data.key?(:ec)
                     @data[:ec] + 1
                   else
                     1
                   end

      # If a valid exception has been passed in, log the information about it
      # In case of just logging an error for things such as HTTP client 5xx
      # responses, an exception/backtrace may not exist.
      if error
        if error.backtrace.is_a?(Array)
          add_stack(stack: error.backtrace)
        end

        if HTTP_SPANS.include?(@data[:n])
          set_tags(:http => { :error => "#{error.class}: #{error.message}" })
        elsif @data[:n] == :activerecord
          @data[:data][:activerecord][:error] = error.message
        else
          log(:error, Time.now, message: error.message, parameters: error.class.to_s)
        end
        error.instance_variable_set(:@instana_logged, true)
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
      @data[:data] = { :sdk => { :name => name.to_sym } }
      @data[:data][:sdk][:custom] = { :tags => {}, :logs => {} }

      if @is_root
        # For custom root spans (via SDK or opentracing), default to entry type
        @data[:k] = 1
        @data[:data][:sdk][:type] = :entry
      else
        @data[:k] = 3
        @data[:data][:sdk][:type] = :intermediate
      end
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
      @ended = true
      # Add this span to the queue for reporting
      ::Instana.processor.on_finish(self)

      self
    end

    #############################################################
    # Accessors
    #############################################################

    # Retrieve the context of this span.
    #
    # @return [Instana::SpanContext]
    #
    def context # rubocop:disable Lint/DuplicateMethods
      @context ||= ::Instana::SpanContext.new(@data[:t], @data[:s], @level, @baggage)
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
    def name=(name)
      if custom?
        @data[:data][:sdk][:name] = name
      else
        @data[:n] = name
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
    def key?(key)
      @data.key?(key.to_sym)
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

    # Check to see if the current span indicates an exit from application
    # code and into an external service
    def exit_span?
      EXIT_SPANS.include?(@data[:n])
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
      unless [Symbol, String].include?(key.class)
        key = key.to_s
      end

      # If <value> is not a Symbol, String, Array, Hash or Numeric - convert to string
      if ![Symbol, String, Array, TrueClass, FalseClass, Hash].include?(value.class) && !value.is_a?(Numeric)
        value = value.to_s
      end

      if custom?
        @data[:data][:sdk][:custom] ||= {}
        @data[:data][:sdk][:custom][:tags] ||= {}
        @data[:data][:sdk][:custom][:tags][key] = value

        if key.to_sym == :'span.kind'
          case value.to_sym
          when ENTRY, SERVER, CONSUMER
            @data[:data][:sdk][:type] = ENTRY
            @data[:k] = 1
          when EXIT, CLIENT, PRODUCER
            @data[:data][:sdk][:type] = EXIT
            @data[:k] = 2
          else
            @data[:data][:sdk][:type] = INTERMEDIATE
            @data[:k] = 3
          end
        end
      elsif value.is_a?(Hash) && @data[:data][key].is_a?(Hash)
        @data[:data][key].merge!(value)
      else
        @data[:data][key] = value
      end
      self
    end

    # Helper method to add multiple tags to this span
    #
    # @params tags [Hash]
    # @return [Span]
    #
    def set_tags(tags) # rubocop:disable Naming
      return unless tags.is_a?(Hash)

      tags.each do |k, v|
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
        @context ||= ::Instana::SpanContext.new(@data[:t], @data[:s], @level, @baggage)
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
      tags = if custom?
               @data[:data][:sdk][:custom][:tags]
             else
               @data[:data]
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
      Instana.logger.debug { "#{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}" }
    end

    # Finish the {Span}
    # Spec: OpenTracing API
    #
    # @param end_time [Time] custom end time, if not now
    #
    def finish(end_time = ::Instana::Util.now_in_ms)
      close(end_time)
      self
    end

    def recording?
      !@ended
    end

    # Set attribute
    #
    # Note that the OpenTelemetry project
    # {https://github.com/open-telemetry/opentelemetry-specification/blob/master/specification/data-semantic-conventions.md
    # documents} certain "standard attributes" that have prescribed semantic
    # meanings.
    #
    # @param [String] key
    # @param [String, Boolean, Numeric, Array<String, Numeric, Boolean>] value
    #   Values must be non-nil and (array of) string, boolean or numeric type.
    #   Array values must not contain nil elements and all elements must be of
    #   the same basic type (string, numeric, boolean).
    #
    # @return [self] returns itself
    def set_attribute(key, value)
      @data ||= {}
      @data[key] = value
      self
    end
    # alias []= set_attribute

    # Add attributes
    #
    # Note that the OpenTelemetry project
    # {https://github.com/open-telemetry/opentelemetry-specification/blob/master/specification/data-semantic-conventions.md
    # documents} certain "standard attributes" that have prescribed semantic
    # meanings.
    #
    # @param [Hash{String => String, Numeric, Boolean, Array<String, Numeric, Boolean>}] attributes
    #   Values must be non-nil and (array of) string, boolean or numeric type.
    #   Array values must not contain nil elements and all elements must be of
    #   the same basic type (string, numeric, boolean).
    #
    # @return [self] returns itself
    def add_attributes(attributes)
      @data ||= {}
      @data.merge!(attributes)
      self
    end

    # Add a link to a {Span}.
    #
    # Adding links at span creation using the `links` option is preferred
    # to calling add_link later, because head sampling decisions can only
    # consider information present during span creation.
    #
    # Example:
    #
    #   span.add_link(OpenTelemetry::Trace::Link.new(span_to_link_from.context))
    #
    # Note that the OpenTelemetry project
    # {https://github.com/open-telemetry/opentelemetry-specification/blob/master/specification/data-semantic-conventions.md
    # documents} certain "standard attributes" that have prescribed semantic
    # meanings.
    #
    # @param [OpenTelemetry::Trace::Link] the link object to add on the {Span}.
    #
    # @return [self] returns itself
    def add_link(_link)
      self
    end

    # Add an event to a {Span}.
    #
    # Example:
    #
    #   span.add_event('event', attributes: {'eager' => true})
    #
    # Note that the OpenTelemetry project
    # {https://github.com/open-telemetry/opentelemetry-specification/blob/master/specification/data-semantic-conventions.md
    # documents} certain "standard event names and keys" which have
    # prescribed semantic meanings.
    #
    # @param [String] name Name of the event.
    # @param [optional Hash{String => String, Numeric, Boolean, Array<String, Numeric, Boolean>}]
    #   attributes One or more key:value pairs, where the keys must be
    #   strings and the values may be (array of) string, boolean or numeric
    #   type.
    # @param [optional Time] timestamp Optional timestamp for the event.
    #
    # @return [self] returns itself
    def add_event(_name, attributes: nil, timestamp: nil) # rubocop:disable Lint/UnusedMethodArgument
      self
    end

    # Sets the Status to the Span
    #
    # If used, this will override the default Span status. Default status is unset.
    #
    # Only the value of the last call will be recorded, and implementations
    # are free to ignore previous calls.
    #
    # @param [Status] status The new status, which overrides the default Span
    #   status, which is OK.
    #
    # @return [void]
    def status=(status); end
  end
end
