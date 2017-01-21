module Instana
  module Instrumentation
    module PostgreSQLAdapter
      IGNORED_PAYLOADS = %w(SCHEMA EXPLAIN CACHE).freeze
      EXPLAINED_SQLS = /\A\s*(with|select|update|delete|insert)\b/i

      # This module supports instrumenting ActiveRecord with the postgresql adapter.  Only
      # versions >= 3.1 are supported.
      #
      def self.included(klass)
        if (::ActiveRecord::VERSION::MAJOR == 3 && ::ActiveRecord::VERSION::MINOR > 0) ||
             ::ActiveRecord::VERSION::MAJOR >= 4

          # ActiveRecord 3.1 and up
          Instana::Util.method_alias(klass, :exec_query)
          Instana::Util.method_alias(klass, :exec_delete)

          @@sanitize_regexp = Regexp.new('(\'[\s\S][^\']*\'|\d*\.\d+|\d+|NULL)', Regexp::IGNORECASE)
        end
      end

      # Collect up this DB connection info for reporting.
      #
      # @param sql [String]
      # @return [Hash] Hash of collected KVs
      #
      def collect(sql)
        payload = { :activerecord => {} }
        payload[:activerecord][:sql] = sql.gsub(@@sanitize_regexp, '?')
        payload[:activerecord][:adapter] = @config[:adapter]
        payload[:activerecord][:host] = @config[:host]
        payload[:activerecord][:db] = @config[:database]
        payload[:activerecord][:username] = @config[:username]
        payload
      end

      # In the spirit of ::ActiveRecord::ExplainSubscriber.ignore_payload?  There are
      # only certain calls that we're interested in tracing.  e.g. No use to instrument
      # framework caches.
      #
      # @param payload [String]
      # @return [Boolean]
      #
      def ignore_payload?(name, sql)
        IGNORED_PAYLOADS.include?(name) || sql !~ EXPLAINED_SQLS
      end

      def exec_query_with_instana(sql, name = 'SQL', binds = [], *args)
        if !::Instana.tracer.tracing? || ignore_payload?(name, sql)
          return exec_query_without_instana(sql, name, binds, *args)
        end

        kv_payload = collect(sql)
        ::Instana.tracer.trace(:activerecord, kv_payload) do
          exec_query_without_instana(sql, name, binds, *args)
        end
      end

      def exec_delete_with_instana(sql, name = nil, binds = [])
        if !::Instana.tracer.tracing? || ignore_payload?(name, sql)
          return exec_delete_without_instana(sql, name, binds)
        end

        kv_payload = collect(sql)
        ::Instana.tracer.trace(:activerecord, kv_payload) do
          exec_delete_without_instana(sql, name, binds)
        end
      end
    end
  end
end
