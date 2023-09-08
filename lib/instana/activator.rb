# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2021

module Instana
  class Activator
    class << self
      attr_reader :trace_point, :activators

      def start
        # :nocov:
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

DIRECTORY_OF_ACTIVATORS = "#{__dir__}/activators/".freeze

def activated_set
  all_activators = Set.new(
    Dir["*.rb", base: DIRECTORY_OF_ACTIVATORS].map do |f|
      File.basename(f, '.rb')
    end
  )

  if ENV['INSTANA_ACTIVATE_SET']
    selected_activators = Set.new(ENV.fetch('INSTANA_ACTIVATE_SET', '').split(','))
    all_activators & selected_activators
  else
    all_activators
  end
end

def require_selected_activator_files
  activated_set.each do |f|
    require("#{DIRECTORY_OF_ACTIVATORS}#{f}.rb")
  end
end

require_selected_activator_files
