module Instana
  module Instrumentation
    module PostgreSQLAdapter
      IGNORED_PAYLOADS = %w(SCHEMA EXPLAIN CACHE).freeze
      IGNORED_SQL = %w(BEGIN COMMIT)
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
          Instana::Util.method_alias(klass, :execute)

          @@sanitize_regexp = Regexp.new('(\'[\s\S][^\']*\'|\d*\.\d+|\d+|NULL)', Regexp::IGNORECASE)
        end
      end

      # Collect up this DB connection info for reporting.
      #
      # @param sql [String]
      # @return [Hash] Hash of collected KVs
      #
      def collect(sql, binds = nil)
        payload = { :activerecord => {} }

        payload[:activerecord][:adapter] = @config[:adapter]
        payload[:activerecord][:host] = @config[:host]
        payload[:activerecord][:db] = @config[:database]
        payload[:activerecord][:username] = @config[:username]

        if ::Instana.config[:sanitize_sql]
          payload[:activerecord][:sql] = sql.gsub(@@sanitize_regexp, '?')
        else
          # No sanitization so raw SQL and collect up binds
          payload[:activerecord][:sql] = sql

          # FIXME: Only works on Rails 5 as the bind format varied in previous versions of Rails
          if binds.is_a?(Array)
            raw_binds = []
            binds.each { |x| raw_binds << x.value_before_type_cast }
            payload[:activerecord][:binds] = raw_binds
          end
        end

        payload
      rescue Exception => e
        ::Instana.logger.debug { "#{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}" }
      ensure
        return payload
      end

      # In the spirit of ::ActiveRecord::ExplainSubscriber.ignore_payload?  There are
      # only certain calls that we're interested in tracing.  e.g. No use to instrument
      # framework caches.
      #
      # @param payload [String]
      # @return [Boolean]
      #
      def ignore_payload?(name, sql)
        IGNORED_PAYLOADS.include?(name) || IGNORED_SQL.include?(sql)
      end

      def exec_query_with_instana(sql, name = 'SQL', binds = [], *args)
        if !::Instana.tracer.tracing? || ignore_payload?(name, sql)
          return exec_query_without_instana(sql, name, binds, *args)
        end

        kv_payload = collect(sql, binds)
        ::Instana.tracer.trace(:activerecord, kv_payload) do
          exec_query_without_instana(sql, name, binds, *args)
        end
      end

      def exec_delete_with_instana(sql, name = nil, binds = [])
        if !::Instana.tracer.tracing? || ignore_payload?(name, sql)
          return exec_delete_without_instana(sql, name, binds)
        end

        kv_payload = collect(sql, binds)
        ::Instana.tracer.trace(:activerecord, kv_payload) do
          exec_delete_without_instana(sql, name, binds)
        end
      end

      def execute_with_instana(sql, name = nil)
        if !::Instana.tracer.tracing? || ignore_payload?(name, sql)
          return execute_without_instana(sql, name)
        end

        kv_payload = collect(sql)
        ::Instana.tracer.trace(:activerecord, kv_payload) do
          execute_without_instana(sql, name)
        end
      end
    end
  end
end
