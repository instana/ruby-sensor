module Instana
  class Trace
    # @return [Integer] the ID for this trace
    attr_reader :id

    # The collection of `Span` for this trace
    # @return [Set] the collection of spans for this trace
    attr_reader :spans

    # The currently active span
    attr_reader :current_span

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
    def initialize(name, kvs = nil, incoming_context = {}, start_time = ::Instana::Util.now_in_ms)
      # The collection of spans that make
      # up this trace.
      @spans = Set.new

      # Generate a random 64bit ID for this trace
      @id = ::Instana::Util.generate_id

      # Indicates the time when this trace was started.  Used to timeout
      # traces that have asynchronous spans that never close out.
      @started_at = Time.now

      # This is a new trace so open the first span with the proper
      # root span IDs.
      @current_span = Span.new(name, @id, start_time: start_time)
      @current_span.set_tags(kvs) if kvs

      # Handle potential incoming context
      if !incoming_context || incoming_context.empty?
        # No incoming context. Set trace ID the same
        # as this first span.
        @current_span[:s] = @id
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
    def new_span(name, kvs = nil, start_time = ::Instana::Util.now_in_ms, child_of = nil)
      return unless @current_span

      if child_of && child_of.is_a?(::Instana::Span)
        new_span = Span.new(name, @id, parent_id: child_of.id, start_time: start_time)
        new_span.parent = child_of
        new_span.baggage = child_of.baggage.dup
      else
        new_span = Span.new(name, @id, parent_id: @current_span.id, start_time: start_time)
        new_span.parent = @current_span
        new_span.baggage = @current_span.baggage.dup
      end
      new_span.set_tags(kvs) if kvs

      @spans.add(new_span)
      @current_span = new_span
    end

    # Add KVs to the current span
    #
    # @param span [Span] the span to add kvs to or otherwise the current span
    # @param kvs [Hash] list of key values to be reported in the span
    #
    def add_info(kvs, span = nil)
      return unless @current_span
      span ||= @current_span

      # Pass on to the OT span interface which will properly
      # apply KVs based on span type
      span.set_tags(kvs)
    end

    # Log an error into the current span
    #
    # @param e [Exception] Add exception to the current span
    #
    def add_error(e, span = nil)
      # Return if we've already logged this exception and it
      # is just propogating up the spans.
      return if e && e.instance_variable_get(:@instana_logged) || @current_span.nil?
      span ||= @current_span
      span.add_error(e)
    end

    # Close out the current span and set the parent as
    # the current span
    #
    # @param kvs [Hash] list of key values to be reported in the span
    #
    def end_span(kvs = {}, end_time = ::Instana::Util.now_in_ms)
      return unless @current_span

      @current_span.close(end_time)
      add_info(kvs) if kvs && !kvs.empty?
      @current_span = @current_span.parent unless @current_span.is_root
    end
    alias finish end_span

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
    def new_async_span(name, kvs = {})
      new_span = Span.new(name, @id, parent_id: @current_span.id)
      new_span.set_tags(kvs) unless kvs.empty?
      new_span.parent = @current_span

      # Add the new span to the span collection
      @spans.add(new_span)
      new_span
    end

    # Log info into an asynchronous span
    #
    # @param kvs [Hash] list of key values to be reported in the span
    # @param span [Span] the span of this Async op (previously returned
    #   from `log_async_entry`)
    #
    def add_async_info(kvs, span)
      span.set_tags(kvs)
    end

    # Log an error into an asynchronous span
    #
    # @param e [Exception] Add exception to the current span
    # @param span [Span] the span of this Async op (previously returned
    #   from `log_async_entry`)
    #
    def add_async_error(e, span)
      span.add_error(e)
    end

    # End an asynchronous span
    #
    # @param name [Symbol] the name of the span
    # @param kvs [Hash] list of key values to be reported in the span
    # @param span [Span] the span of this Async op (previously returned
    #   from `log_async_entry`)
    #
    def end_async_span(kvs = {}, span)
      span.set_tags(kvs) unless kvs.empty?
      span.close
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
      true
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
      span.configure_custom(name, kvs)
    end

    # Adds the passed in backtrace to the specified span.  Backtrace can be one
    # generated from Kernel.caller or one attached to an exception
    #
    # @param bt [Array] the backtrace
    # @param limit [Integer] Limit the backtrace to the top <limit> frames
    # @param span [Span] the span to add the backtrace to or if unspecified
    #   the current span
    #
    def add_backtrace_to_span(bt, limit = nil, span)
      frame_count = 0
      span[:stack] = []

      bt.each do |i|
        # If the stack has the full instana gem version in it's path
        # then don't include that frame. Also don't exclude the Rack module.
        if !i.match(/instana\/instrumentation\/rack.rb/).nil? ||
          (i.match(::Instana::VERSION_FULL).nil? && i.match('lib/instana/').nil?)

          break if limit && frame_count >= limit

          x = i.split(':')

          span[:stack] << {
            :f => x[0],
            :n => x[1],
            :m => x[2]
          }
         frame_count = frame_count + 1 if limit
        end
      end
    end
  end
end
