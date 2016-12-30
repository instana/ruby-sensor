module Instana
  class Span
    attr_accessor :parent

    def initialize(data)
      @data = data
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

    # Indicates whether this span in the root span
    # in the Trace
    #
    # @return [Boolean]
    #
    def is_root?
      @data[:s] == @data[:t]
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

    # Configure this span to be a custom span per the
    # SDK generic span type.
    #
    # @param name [String] name of the span
    # @param kvs [Hash] list of key values to be reported in the span
    #
    def configure_custom(name, kvs)
      self[:n] = :sdk
      self[:data] = { :sdk => { :name => name.to_sym } }

      if kvs.is_a?(Hash)
        self[:data][:sdk][:type] = kvs.key?(:type) ? kvs[:type] : :local

        if kvs.key?(:arguments)
          self[:data][:sdk][:arguments] = kvs[:arguments]
        end

        if kvs.key?(:return)
          self[:data][:sdk][:return] = kvs[:return]
        end
        self[:data][:sdk][:custom] = kvs unless kvs.empty?
      end
      self
    end

    #############################################################
    # OpenTracing Compatibility Methods
    #############################################################

    # Set the name of the operation
    def operation_name=(name)
      self.name = name
    end

    # Span Context
    def context
      { :trace_id => self.trace_id,
        :span_id => self..id }
    end

    # Creates a new {Span}
    #
    # @param tracer [Tracer] the tracer that created this span
    # @param context [SpanContext] the context of the span
    # @return [Span] a new Span
    #
    #def initialize(tracer:, context:)
    #  @span = ::Instana::Span.new
    #end

    # Set a tag value on this span
    #
    # @param key [String] the key of the tag
    # @param value [String, Numeric, Boolean] the value of the tag. If it's not
    # a String, Numeric, or Boolean it will be encoded with to_s
    #
    def set_tag(key, value)
      if span.custom?
        self[:data][:sdk][:custom] = {} unless self[:data][:sdk].key?(:custom)
        self[:data][:sdk][:custom][key] = value
      else
        if !span[:data].key?(key)
          span[:data][key] = value
        elsif value.is_a?(Hash) && span[:data][key].is_a?(Hash)
          span[:data][key].merge!(value)
        else
          span[:data][key] = value
        end
      end
      self
    end

    # Set a baggage item on the span
    #
    # @param key [String] the key of the baggage item
    # @param value [String] the value of the baggage item
    def set_baggage_item(key, value)
      set_tag(key, value)
    end

    # Get a baggage item
    #
    # @param key [String] the key of the baggage item
    # @return Value of the baggage item
    #
    def get_baggage_item(key)
      if span.custom?
        self[:data][:sdk][:custom][key]
      else
        span[:data][key]
      end
    end

    # Add a log entry to this span
    #
    # @param event [String] event name for the log
    # @param timestamp [Time] time of the log
    # @param fields [Hash] Additional information to log
    #
    def log(event = nil, timestamp = (Time.now.to_f * 1000).floor, **fields)
      self[:ts] = timestamp

      if !REGISTERED_SPANS.include?(name.to_sym)
        configure_custom(event, fields)
      else
        self[:n] = name.to_sym
      end
    end

    # Finish the {Span}
    #
    # @param end_time [Time] custom end time, if not now
    #
    def finish(end_time = (Time.now.to_f * 1000).floor)
      self[:d] = end_time - self[:ts]
    end
  end
end
