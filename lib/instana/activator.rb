module Instana
  class Activator
    class << self
      attr_reader :trace_point, :activators

      def start
        @trace_point = TracePoint.new(:end) do
          activated = ::Instana::Activator.call
          ::Instana.logger.debug { "Activated #{activated.join(', ')}" } unless activated.empty?
        end
        @trace_point.enable
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
    end

    def call
      instrument if can_instrument?
    end
  end
end
