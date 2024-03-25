# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2021

module Instana
  module Activators
    class Redis < Activator
      def can_instrument?
        defined?(::Redis) && defined?(::Redis::Client) && ::Instana.config[:redis][:enabled] &&
          (Gem::Specification.find_by_name('redis').version < Gem::Version.new('5.0') || defined?(::RedisClient))
      end

      def instrument
        require 'instana/instrumentation/redis'

        if Gem::Specification.find_by_name('redis').version >= Gem::Version.new('5.0')
          ::RedisClient.prepend(::Instana::RedisInstrumentation)
        else
          ::Redis::Client.prepend(::Instana::RedisInstrumentation)
        end

        true
      end
    end
  end
end
