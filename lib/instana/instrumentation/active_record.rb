# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2021

module Instana
  module Instrumentation
    module ActiveRecord
      IGNORED_NAMES = %w[SCHEMA EXPLAIN CACHE].freeze
      IGNORED_SQL = %w[BEGIN COMMIT SET].freeze
      SANITIZE_REGEXP = /('[\s\S][^']*'|\d*\.\d+|\d+|NULL)/i.freeze

      def log(sql, name = 'SQL', binds = [], *args, **kwargs)
        call_payload = {
          activerecord: {
            adapter: @config[:adapter],
            host: @config[:host],
            username: @config[:username],
            db: @config[:database],
            sql: maybe_sanitize(sql)
          }
        }

        if binds.all? { |b| b.respond_to?(:value_before_type_cast) } && !::Instana.config[:sanitize_sql]
          mapped = binds.map(&:value_before_type_cast)
          call_payload[:activerecord][:binds] = mapped
        end

        maybe_trace(call_payload, name) { super(sql, name, binds, *args, **kwargs) }
      end

      private

      def maybe_sanitize(sql)
        ::Instana.config[:sanitize_sql] ? sql.gsub(SANITIZE_REGEXP, '?') : sql
      end

      def maybe_trace(call_payload, name, &blk)
        if ::Instana.tracer.tracing? && !ignored?(call_payload, name)
          ::Instana.tracer.trace(:activerecord, call_payload, &blk)
        else
          yield
        end
      end

      def ignored?(call_payload, name)
        IGNORED_NAMES.include?(name) ||
          IGNORED_SQL.any? { |s| call_payload[:activerecord][:sql].upcase.start_with?(s) }
      end
    end
  end
end
