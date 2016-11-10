module Instana
  class Trace
    attr_accessor :id
    attr_reader :spans

    def initialize(name, kvs, parent_id = nil)
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
        :t => @id,      # Trace ID (same as :s for root span)
        :n => name,     # Span name
        :ts => ts_now,  # Timestamp
        :ta => :ruby,   # Agent
        :data => kvs,   # Data
        :f => { :e => Process.pid, :h => :agent_id } # Entity Source
      })
      @spans.add(@current_span)
    end

    ##
    # new_span
    #
    # Start a new span as a child of @current_span
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

    ##
    # end_span
    #
    # Close out the current span and set the parent as
    # the @current_span
    #
    def end_span(kvs = {})
      @current_span[:d] = ts_now - @current_span[:ts]
      add_info(kvs) unless kvs.empty?

      # Look up the parent span and set as current
      candidate = nil
      @spans.each do |i|
        if @current_span[:p] == i[:s]
          candidate = i
        end
      end
      @current_span = candidate
    end

    ##
    # add_info
    #
    # Add KVs to the @current_span
    #
    def add_info(kvs)
      @current_span[:data].merge!(kvs)
    end

    ##
    # add_error
    #
    # Log an error into the current span
    #
    def add_error(e)
      @current_span[:error] = true
    end

    ##
    # finish
    #
    # This should be called only on the root span to end the trace.
    # Once closed out, the trace is then queued for reporting.
    #
    def finish(kvs = {})
      end_span(kvs)
    end

    ##
    # valid?
    #
    # Indicates whether all seems ok with this
    # trace in it's current state.  Should be only
    # called on finished traces.
    #
    def valid?
      # TODO
      true
    end

    ##
    # has_error?
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

    ##
    # ts_now
    #
    # Get the current time in milliseconds
    #
    def ts_now
      (Time.now.to_f * 1000).floor
    end

    ##
    # generate_id
    #
    # Generate a random 64bit ID
    #
    def generate_id
      rand(2**32..2**64-1)
    end
  end
end
