# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2021

module Instana
  module Activators
    class Redis < Activator
      def can_instrument?
        defined?(::Redis) && Gem::Specification.find_by_name('redis').version < Gem::Version.new('5.0') && defined?(::Redis::Client) && ::Instana.config[:redis][:enabled]
      end

      def instrument
        require 'instana/instrumentation/redis'

        ::Redis::Client.prepend(::Instana::RedisInstrumentation)

        true
      end
    end
  end
end
