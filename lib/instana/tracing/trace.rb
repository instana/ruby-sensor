module Instana
  class Trace
    REGISTERED_SPANS = [ :rack, :'net-http', :excon ]
    ENTRY_SPANS = [ :rack ]
    EXIT_SPANS = [ :'net-http', :excon ]

    # @return [Integer] the ID for this trace
    attr_reader :id

    # The collection of `Span` for this trace
    # @return [Set] the collection of spans for this trace
    attr_reader :spans

    # Initializes a new instance of Trace
    #
    # @param name [String] the name of the span to start
    # @param kvs [Hash] list of key values to be reported in the span
    # @param incoming_context [Hash] specifies the incoming context.  At a
    #   minimum, it should specify :trace_id and :span_id from the following:
    #     :trace_id the trace ID (must be an unsigned hex-string)
    #     :span_id the ID of the parent span (must be an unsigned hex-string)
    #     :level specifies data collection level (optional)
    #
    def initialize(name, kvs = {}, incoming_context = {})
      # The collection of spans that make
      # up this trace.
      @spans = Set.new

      # Generate a random 64bit ID for this trace
      @id = generate_id

      # Indicates the time when this trace was started.  Used to timeout
      # traces that have asynchronous spans that never close out.
      @started_at = Time.now

      # Indicates if this trace has any asynchronous spans within it
      @has_async = false

      # This is a new trace so open the first span with the proper
      # root span IDs.
      @current_span = Span.new({
        :s => @id,         # Span ID
        :ts => ts_now,     # Timestamp
        :ta => :ruby,      # Agent
        :f => { :e => ::Instana.agent.report_pid, :h => ::Instana.agent.agent_uuid } # Entity Source
      })

      # For entry spans, add a backtrace fingerprint
      if ENTRY_SPANS.include?(name)
        add_stack(2)
      end

      # Check for custom tracing
      if !REGISTERED_SPANS.include?(name.to_sym)
        configure_custom_span(nil, name, kvs)
      else
        @current_span[:n]    = name.to_sym
        @current_span[:data] = kvs
      end

      # Handle potential incoming context
      if incoming_context.empty?
        # No incoming context. Set trace ID the same
        # as this first span.
        @current_span[:t] = @id
      else
        @id = incoming_context[:trace_id]
        @current_span[:t] = incoming_context[:trace_id]
        @current_span[:p] = incoming_context[:span_id]
      end

      @spans.add(@current_span)
    end

    # Start a new span as a child of @current_span
    #
    # @param name [String] the name of the span to start
    # @param kvs [Hash] list of key values to be reported in the span
    #
    def new_span(name, kvs)
      return unless @current_span

      new_span = Span.new({
        :s => generate_id,          # Span ID
        :t => @id,                  # Trace ID (same as :s for root span)
        :p => @current_span.id,     # Parent ID
        :ts => ts_now,              # Timestamp
        :ta => :ruby,               # Agent
        :f => { :e => Process.pid, :h => :agent_id } # Entity Source
      })

      new_span.parent = @current_span
      @spans.add(new_span)
      @current_span = new_span

      # Check for custom tracing
      if !REGISTERED_SPANS.include?(name.to_sym)
        configure_custom_span(nil, name, kvs)
      else
        @current_span[:n]    = name.to_sym
        @current_span[:data] = kvs
      end

      # Attach a backtrace to all exit spans
      if EXIT_SPANS.include?(name)
        add_stack
      end
    end

    # Add KVs to the current span
    #
    # @param span [Span] the span to add kvs to or otherwise the current span
    # @param kvs [Hash] list of key values to be reported in the span
    #
    def add_info(kvs, span = nil)
      span ||= @current_span

      if span.custom?
        if span[:data][:sdk].key?(:custom)
          span[:data][:sdk][:custom].merge!(kvs)
        else
          span[:data][:sdk][:custom] = kvs
        end
      else
        kvs.each_pair do |k,v|
          if !span[:data].key?(k)
            span[:data][k] = v
          elsif v.is_a?(Hash) && span[:data][k].is_a?(Hash)
            span[:data][k].merge!(v)
          else
            span[:data][k] = v
          end
        end
      end
    end

    # Log an error into the current span
    #
    # @param e [Exception] Add exception to the current span
    #
    def add_error(e, span = nil)
      span ||= @current_span

      span[:error] = true

      if span.key?(:ec)
        span[:ec] = span[:ec] + 1
      else
        span[:ec] = 1
      end

      add_info(:log => {
        :message => e.message,
        :parameters => e.class })
    end

    # Close out the current span and set the parent as
    # the current span
    #
    # @param kvs [Hash] list of key values to be reported in the span
    #
    def end_span(kvs = {})
      @current_span[:d] = ts_now - @current_span[:ts]
      add_info(kvs) unless kvs.empty?
      @current_span = @current_span.parent unless @current_span.is_root?
    end

    # Closes out the final span in this trace and runs any finalizer
    # steps required.
    # This should be called only on the root span to end the trace.
    #
    # @param kvs [Hash] list of key values to be reported in the span
    #
    def finish(kvs = {})
      end_span(kvs)
    end

    ###########################################################################
    # Asynchronous Methods
    ###########################################################################

    # Start a new asynchronous span
    #
    # The major differentiator between this method and simple new_span is that
    # this method doesn't affect @current_trace and instead returns an
    # ID pair that can be used later to close out the created async span.
    #
    # @param name [String] the name of the span to start
    # @param kvs [Hash] list of key values to be reported in the span
    #
    def new_async_span(name, kvs)

      new_span = Span.new({
        :s => generate_id,          # Span ID
        :t => @id,                  # Trace ID (same as :s for root span)
        :p => @current_span.id,     # Parent ID
        :ts => ts_now,              # Timestamp
        :ta => :ruby,               # Agent
        :async => true,             # Asynchonous
        :f => { :e => Process.pid, :h => :agent_id } # Entity Source
      })

      new_span.parent = @current_span
      @has_async = true

      # Check for custom tracing
      if !REGISTERED_SPANS.include?(name.to_sym)
        configure_custom_span(new_span, name, kvs)
      else
        new_span[:n]    = name.to_sym
        new_span[:data] = kvs
      end

      # Add the new span to the span collection
      @spans.add(new_span)

      { :trace_id => new_span[:t], :span_id => new_span.id }
    end

    # Log info into an asynchronous span
    #
    # @param kvs [Hash] list of key values to be reported in the span
    # @param span [Span] the span to configure
    #
    def add_async_info(kvs, ids)
      @spans.each do |span|
        if span.id == ids[:span_id]
          add_info(kvs, span)
        end
      end
    end

    # Log an error into an asynchronous span
    #
    # @param span [Span] the span to configure
    # @param e [Exception] Add exception to the current span
    #
    def add_async_error(e, ids)
      @spans.each do |span|
        add_error(e, span) if span.id == ids[:span_id]
      end
    end

    # End an asynchronous span
    #
    # @param name [Symbol] the name of the span
    # @param kvs [Hash] list of key values to be reported in the span
    # @param ids [Hash] the Trace ID and Span ID in the form of
    #   :trace_id => 12345
    #   :span_id => 12345
    #
    def end_async_span(kvs = {}, ids)
      @spans.each do |span|
        if span.id == ids[:span_id]
          span[:d] = ts_now - span[:ts]
          add_info(kvs, span) unless kvs.empty?
        end
      end
    end

    ###########################################################################
    # Validator and Helper Methods
    ###########################################################################

    # Indicates whether all seems ok with this trace in it's current state.
    # Should be only called on finished traces.
    #
    # @return [Boolean] true or false on whether this trace is valid
    #
    def valid?
      @spans.each do |span|
        unless span.key?(:d)
          return false
        end
      end
    end

    # Indicates if every span of this trace has completed.  Useful when
    # asynchronous spans potentially could run longer than the parent trace.
    #
    def complete?
      @spans.each do |span|
        if !span.duration
          return false
        end
      end
      true
    end

    # Indicates whether this trace has any asynchronous spans.
    #
    def has_async?
      @has_async
    end

    # Searches the set of spans and indicates if there
    # is an error logged in one of them.
    #
    # @return [Boolean] true or false indicating the presence
    #   of an error
    #
    def has_error?
      @spans.each do |s|
        if s.key?(:error)
          if s[:error] == true
            return true
          end
        end
      end
      false
    end

    # Get the ID of the current span for this trace.
    # Used often to place in HTTP response headers.
    #
    # @return [Integer] a random 64bit integer
    #
    def current_span_id
      @current_span.id
    end

    # Get the name of the current span.  Supports both registered spans
    # and custom sdk spans.
    #
    def current_span_name
      @current_span.name
    end

    # Check if the current span has the name value of <name>
    #
    # @param name [Symbol] The name to be checked against.
    #
    # @return [Boolean]
    #
    def current_span_name?(name)
      @current_span.name == name
    end

    # For traces that have asynchronous spans, this method indicates
    # whether we have hit the timeout on waiting for those async
    # spans to close out.
    #
    # @return [Boolean]
    #
    def discard?
      # If this trace has async spans that have not closed
      # out in 5 minutes, then it's discarded.
      if has_async? && (Time.now.to_i - @started_at.to_i) > 601
        return true
      end
      false
    end

    private

    # Configure @current_span to be a custom span per the
    # SDK generic span type.
    #
    # @param span [Span] the span to configure or nil
    # @param name [String] name of the span
    # @param kvs [Hash] list of key values to be reported in the span
    #
    def configure_custom_span(span, name, kvs = {})
      span ||= @current_span

      span[:n] = :sdk
      span[:data] = { :sdk => { :name => name.to_sym } }
      span[:data][:sdk][:type] = kvs.key?(:type) ? kvs[:type] : :local

      if kvs.key?(:arguments)
        span[:data][:sdk][:arguments] = kvs[:arguments]
      end

      if kvs.key?(:return)
        span[:data][:sdk][:return] = kvs[:return]
      end
      span[:data][:sdk][:custom] = kvs unless kvs.empty?
      #span[:data][:sdk][:custom][:tags] = {}
      #span[:data][:sdk][:custom][:logs] = {}
    end

    # Locates the span in the current_trace or
    # in the staging queue.  This is generally used by async
    # operations.
    #
    # @param ids [Hash] the Trace ID and Span ID in the form of
    #   :trace_id => 12345
    #   :span_id => 12345
    #
    # @return [Span]
    #
    def find_span(ids)
      if ids[:trace_id] == @id
        @spans.each do |s|
          return s if s[:s] == ids[:span_id]
        end
      else
        #::Instana.processor.staged_trace(
      end
    end

    # Adds a backtrace to the passed in span or on
    # @current_span if not.
    #
    def add_stack(n = nil, span = nil)
      span ||= @current_span
      span[:stack] = []

      if n
        backtrace = Kernel.caller[0..(n-1)]
      else
        backtrace = Kernel.caller
      end

      backtrace.each do |i|
        if !i.match(::Instana::VERSION_FULL).nil?
          x = i.split(':')

          # Don't include Instana gem frames
          span[:stack] << {
            :c => x[0],
            :n => x[1],
            :m => x[2]
          }
        end
      end
    end

    # Get the current time in milliseconds
    #
    # @return [Integer] the current time in milliseconds
    #
    def ts_now
      (Time.now.to_f * 1000).floor
    end

    # Generate a random 64bit ID
    #
    # @return [Integer] a random 64bit integer
    #
    def generate_id
      # Max value is 9223372036854775807 (signed long in Java)
      rand(-2**63..2**63-1)
    end
  end
end
