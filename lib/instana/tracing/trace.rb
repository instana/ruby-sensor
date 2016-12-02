module Instana
  class Trace
    REGISTERED_SPANS = [ :rack, :'net-http' ]

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
    #   minimum, it should specify :trace_id and :parent_id from the following:
    #     :trace_id the trace ID (must be an unsigned hex-string)
    #     :parent_id the ID of the parent span (must be an unsigned hex-string)
    #     :level specifies data collection level (optional)
    #
    def initialize(name, kvs = {}, incoming_context = {})
      # The collection of spans that make
      # up this trace.
      @spans = Set.new

      # The current active span
      @current_span = nil

      # Generate a random 64bit ID for this trace
      @id = generate_id

      # This is a new trace so open the first span with the proper
      # root span IDs.
      @current_span = Span.new({
        :s => @id,         # Span ID
        :ts => ts_now,     # Timestamp
        :ta => :ruby,      # Agent
        :f => { :e => ::Instana.agent.report_pid, :h => ::Instana.agent.agent_uuid } # Entity Source
      })

      # Check for custom tracing
      if !REGISTERED_SPANS.include?(name.to_sym)
        configure_custom_span(name, kvs)
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
        @current_span[:p] = incoming_context[:parent_id]
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
        :p => @current_span[:s],    # Parent ID
        :ts => ts_now,              # Timestamp
        :ta => :ruby,               # Agent
        :f => { :e => Process.pid, :h => :agent_id } # Entity Source
      })

      new_span.parent = @current_span
      @spans.add(new_span)
      @current_span = new_span

      # Check for custom tracing
      if !REGISTERED_SPANS.include?(name.to_sym)
        configure_custom_span(name, kvs)
      else
        @current_span[:n]    = name.to_sym
        @current_span[:data] = kvs
      end
    end

    # Add KVs to the current span
    #
    # @param kvs [Hash] list of key values to be reported in the span
    #
    def add_info(kvs)
      if @current_span.custom?
        if @current_span[:data][:sdk].key?(:custom)
          @current_span[:data][:sdk][:custom].merge!(kvs)
        else
          @current_span[:data][:sdk][:custom] = kvs
        end
      else
        @current_span[:data].merge!(kvs)
      end
    end

    # Log an error into the current span
    #
    # @param e [Exception] Add exception to the current span
    #
    def add_error(e)
      @current_span[:error] = true

      if @current_span.key?(:ec)
        @current_span[:ec] = @current_span[:ec] + 1
      else
        @current_span[:ec] = 1
      end

      #if e.backtrace && e.backtrace.is_a?(Array)
      #  @current_span[:stack] = []
      #  e.backtrace.each do |x|
      #    file, line, method = x.split(':')
      #    @current_span[:stack] << {
      #      :f => file,
      #      :n => line
      #      #:m => method
      #    }
      #  end
      #end
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

    # Indicates whether all seems ok with this
    # trace in it's current state.  Should be only
    # called on finished traces.
    #
    # @return [Boolean] true or false on whether this trace is valid
    #
    def valid?
      # TODO
      true
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

    private

    # Configure @current_span to be a custom span per the
    # SDK generic span type.
    #
    def configure_custom_span(name, kvs = {})
      @current_span[:n] = :sdk
      @current_span[:data] = { :sdk => { :name => name.to_sym } }
      @current_span[:data][:sdk][:type] = kvs.key?(:type) ? kvs[:type] : :local

      if kvs.key?(:arguments)
        @current_span[:data][:sdk][:arguments] = kvs[:arguments]
      end

      if kvs.key?(:return)
        @current_span[:data][:sdk][:return] = kvs[:return]
      end
      @current_span[:data][:sdk][:custom] = kvs unless kvs.empty?
      #@current_span[:data][:sdk][:custom][:tags] = {}
      #@current_span[:data][:sdk][:custom][:logs] = {}
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
