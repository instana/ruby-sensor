module Instana
  class Trace
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
        :s => @id,      # Span ID
        :n => name,     # Span name
        :ts => ts_now,  # Timestamp
        :ta => :ruby,   # Agent
        :data => kvs,   # Data
        :f => { :e => ::Instana.agent.report_pid, :h => ::Instana.agent.agent_uuid } # Entity Source
      })

      # Handle potential incoming context
      if incoming_context.empty?
        # No incoming context. Set trace ID the same
        # as this first span.
        @current_span[:t] = @id
      else
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
        :n => name,                 # Span name
        :ts => ts_now,              # Timestamp
        :ta => :ruby,               # Agent
        :data => kvs,               # Data
        :f => { :e => Process.pid, :h => :agent_id } # Entity Source
      })
      new_span.parent = @current_span
      @spans.add(new_span)
      @current_span = new_span
    end

    # Add KVs to the current span
    #
    # @param kvs [Hash] list of key values to be reported in the span
    #
    def add_info(kvs)
      @current_span[:data].merge!(kvs)
    end

    # Log an error into the current span
    #
    # @param e [Exception] Add exception to the current span
    #
    def add_error(e)
      @current_span[:error] = true
    end

    # Close out the current span and set the parent as
    # the current span
    #
    # @param kvs [Hash] list of key values to be reported in the span
    #
    def end_span(kvs = {})
      @current_span[:d] = ts_now - @current_span[:ts]
      add_info(kvs) unless kvs.empty?
      @current_span = @current_span.parent
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
          return s[:error]
        end
      end
      false
    end

    private

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
      rand(2**32..2**64-1)
    end
  end
end
