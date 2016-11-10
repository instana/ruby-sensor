module Instana
  class Span
    def initialize(data)
      @data = data
    end

    def parent_id
      @data[:p]
    end

    def [](key)
      @data[key.to_sym]
    end

    def []=(key, value)
      @data[key.to_sym] = value
    end

    def key?(k)
      @data.key?(k.to_sym)
    end
  end
end
