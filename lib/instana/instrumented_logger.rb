# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2021

module Instana
  class InstrumentedLogger < Logger
    LEVEL_LABELS = %w[Debug Info Warn Error Fatal Any].freeze

    def instana_log_level
      WARN
    end

    def add(severity, message = nil, progname = nil)
      severity ||= UNKNOWN

      if severity >= instana_log_level && ::Instana.tracer.tracing?
        tags = {
          level: LEVEL_LABELS[severity],
          message: "#{message} #{progname}".strip
        }
        Instana.tracer.in_span(:log, attributes: {log: tags}) {}
      end

      super(severity, message, progname)
    end
  end
end
