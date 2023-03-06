# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2016

module Instana
  class Span
    REGISTERED_SPANS = [ :actioncontroller, :actionview, :activerecord, :excon,
                         :memcache, :'net-http', :rack, :render, :'rpc-client',
                         :'rpc-server', :'sidekiq-client', :'sidekiq-worker',
                         :redis, :'resque-client', :'resque-worker', :'graphql.server', :dynamodb, :s3, :sns, :sqs, :'aws.lambda.entry', :activejob, :log, :"mail.actionmailer",
                         :"aws.lambda.invoke", :mongo  ].freeze
    ENTRY_SPANS = [ :rack, :'resque-worker', :'rpc-server', :'sidekiq-worker', :'graphql.server', :sqs,
                    :'aws.lambda.entry' ].freeze
    EXIT_SPANS = [ :activerecord, :excon, :'net-http', :'resque-client',
                   :'rpc-client', :'sidekiq-client', :redis, :dynamodb, :s3, :sns, :sqs, :log, :"mail.actionmailer",
                   :"aws.lambda.invoke", :mongo ].freeze
    HTTP_SPANS = [ :rack, :excon, :'net-http' ].freeze

    attr_accessor :parent
    attr_accessor :baggage
    attr_accessor :is_root
    attr_accessor :context

    def initialize(name, parent_ctx: nil, start_time: ::Instana::Util.now_in_ms)
      @data = {}

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
          @data[:t] = ::Instana::Util.generate_id
        end

        @data[:s] = ::Instana::Util.generate_id # Span ID

        @baggage = parent_ctx.baggage.dup
        @level = parent_ctx.level
      else
        # No parent specified so we're starting a new Trace - this will be the root span
        @is_root = true
        @level = 1

        id = ::Instana::Util.generate_id
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
      if start_time.is_a?(Time)
        @data[:ts] = ::Instana::Util.time_to_ms(start_time)
      else
        @data[:ts] = start_time
      end

      # Check for custom tracing
      if REGISTERED_SPANS.include?(name.to_sym)
        @data[:n] = name.to_sym
      else
        configure_custom(name)
      end

      ::Instana.processor.start_span(self)

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
        elsif @data[:n] == :activerecord
          @data[:data][:activerecord][:error] = e.message
        else
          log(:error, Time.now, message: e.message, parameters: e.class.to_s)
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

      # Add this span to the queue for reporting
      ::Instana.processor.add_span(self)

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
      if ![Symbol, String].include?(key.class)
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
          when :entry, :server, :consumer
            @data[:data][:sdk][:type] = :entry
            @data[:k] = 1
          when :exit, :client, :producer
            @data[:data][:sdk][:type] = :exit
            @data[:k] = 2
          else
            @data[:data][:sdk][:type] = :intermediate
            @data[:k] = 3
          end
        end
      else
        if value.is_a?(Hash) && @data[:data][key].is_a?(Hash)
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
      if custom?
        tags = @data[:data][:sdk][:custom][:tags]
      else
        tags = @data[:data]
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
  end
end
