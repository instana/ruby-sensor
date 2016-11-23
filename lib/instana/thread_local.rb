module Instana
  module ThreadLocal
    def thread_local(name)
      key = "__#{self}_#{name}__".intern

      define_method(name) do
        Thread.current[key]
      end

      define_method(name.to_s + '=') do |value|
        Thread.current[key] = value
      end
    end
  end
end
