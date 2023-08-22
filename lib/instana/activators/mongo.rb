# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2021

module Instana
  module Activators
    class Mongo < Activator
      def can_instrument?
        defined?(::Mongo::Client) && defined?(::Mongo::Monitoring::Global) && ::Instana.config[:mongo][:enabled]
      end

      def instrument
        require 'instana/instrumentation/mongo'

        ::Mongo::Monitoring::Global.subscribe(
          ::Mongo::Monitoring::COMMAND,
          ::Instana::Mongo.new
        )

        true
      end
    end
  end
end
