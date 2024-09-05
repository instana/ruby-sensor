# (c) Copyright IBM Corp. 2024

module Instana
  module Instrumentation
    module Sequel
      IGNORED_SQL = %w[BEGIN COMMIT SET].freeze
      VERSION_SELECT_STATEMENT = "SELECT VERSION()".freeze
      SANITIZE_REGEXP = /('[\s\S][^']*'|\d*\.\d+|\d+|NULL)/i.freeze

      def log_connection_yield(sql, conn, *args)
        call_payload = {
          sequel: {
            adapter: opts[:adapter],
            host: opts[:host],
            username: opts[:user],
            db: opts[:database],
            sql: maybe_sanitize(sql)
          }
        }
        maybe_trace(call_payload) { super(sql, conn, *args) }
      end

      private

      def maybe_sanitize(sql)
        ::Instana.config[:sanitize_sql] ? sql.gsub(SANITIZE_REGEXP, '?') : sql
      end

      def maybe_trace(call_payload, &blk)
        if ::Instana.tracer.tracing? && !ignored?(call_payload)
          ::Instana.tracer.trace(:sequel, call_payload, &blk)
        else
          yield
        end
      end

      def ignored?(call_payload)
        IGNORED_SQL.any? { |s| call_payload[:sequel][:sql].upcase.start_with?(s) } || call_payload[:sequel][:sql].upcase == VERSION_SELECT_STATEMENT
      end
    end
  end
end
