module Instana
  module Instrumentation
    module ActiveRecordPg
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
        end
      end

      # Collect up this DB connection info for reporting.
      #
      # @param sql [String]
      # @param name [String]
      # @param binds [Array]
      #
      def collect(sql, name = nil, binds = [])
        payload = { :activerecord => {} }
        payload[:activerecord][:sql] = sql
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
      def ignore_payload?(payload, sql)
        IGNORED_PAYLOADS.include?(:name) || sql !~ EXPLAINED_SQLS
      end

      def exec_query_with_instana(sql, name = 'SQL', binds = [], *args)
        if !::Instana.tracer.tracing? || ignore_payload?(name, sql)
          return exec_query_without_instana(sql, name, binds, *args)
        end

        kv_payload = collect(sql, name, binds)
        ::Instana.tracer.trace(:activerecord, kv_payload) do
          exec_query_without_instana(sql, name, binds, *args)
        end
      end

      def exec_delete_with_instana(sql, name = nil, binds = [])
        if !::Instana.tracer.tracing? || ignore_payload?(name, sql)
          return exec_delete_without_instana(sql, name, binds)
        end

        kv_payload = collect(sql, name, binds)
        ::Instana.tracer.trace(:activerecord, kv_payload) do
          exec_delete_without_instana(sql, name, binds)
        end
      end
    end
  end
end

if defined?(::ActiveRecord) && ::Instana.config[:active_record][:enabled]
  case ActiveRecord::Base.connection.adapter_name.downcase
  when 'mysql'
    ::Instana.logger.warn "Still undone: mysql"
  when 'mysql2'
    ::Instana.logger.warn "Still undone: mysql2"
  when 'postgresql'
    ::Instana.logger.warn "Instrumenting ActiveRecord (postgresql)"
    ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.send(:include, ::Instana::Instrumentation::ActiveRecordPg)
  else
    ::Instana.logger.warn "Unsupported ActiveRecord adapter: #{ActiveRecord::Base.connection.adapter_name.downcase}"
  end
end
