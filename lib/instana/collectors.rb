require 'timers'
require 'instana/collectors/gc'
require 'instana/collectors/memory'
require 'instana/collectors/thread'

module Instana
  module Collector
    class << self
      attr_accessor :interval

      ##
      # collect_and_report
      #
      # Run through each collector, let them collect up
      # data and then report what we have via the agent
      #
      # @return Boolean true on success
      #
      def collect_and_report
        payload = {}

        ::Instana.collectors.each do |c|
          metrics = c.collect
          if metrics
            payload[c.payload_key] = metrics
          else
            payload.delete(c.payload_key)
          end
        end

        if ENV['INSTANA_GEM_TEST']
          true
        else
          # Report all the collected goodies
          ::Instana.agent.report_entity_data(payload)
        end
      end
    end
  end
end

if ENV.key?('INSTANA_GEM_DEV')
  ::Instana::Collector.interval = 3
else
  ::Instana::Collector.interval = 1
end
