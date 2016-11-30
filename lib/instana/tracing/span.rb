module Instana
  class Span
    attr_accessor :parent

    def initialize(data)
      @data = data
    end

    def id
      @data[:s]
    end

    def parent_id
      @data[:p]
    end

    def is_root?
      @data[:s] == @data[:t]
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

    def raw
      @data
    end

    def custom?
      @data[:n] == :sdk
    end
  end
end
