# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2021

module Instana
  class Activator
    class << self
      attr_reader :trace_point, :activators

      def start
        @trace_point = TracePoint.new(:end) do
          activated = ::Instana::Activator.call
          ::Instana.logger.debug { "Activated #{activated.join(', ')}" } unless activated.empty?
        end

        @trace_point.enable if enabled?
        # :nocov:
      end

      def call
        @activators ||= []
        activated, @activators = @activators.partition(&:call)
        activated
      end

      def inherited(subclass)
        super(subclass)

        @activators ||= []
        @activators << subclass.new
      end

      private

      def enabled?
        ENV.fetch('INSTANA_DISABLE_AUTO_INSTR', 'false').eql?('false') || !ENV.key?('INSTANA_DISABLE')
      end
    end

    def call
      instrument if can_instrument?
    end
  end
end

Dir["#{__dir__}/activators/*.rb"]
  .sort
  .select do |f|
  # :nocov:
  if ENV['INSTANA_ACTIVATE_SET']
    base = File.basename(f, '.rb')
    ENV.fetch('INSTANA_ACTIVATE_SET', '').split(',').include?(base)
  else
    true
  end
  # :nocov:
end
  .each { |f| require(f) }
