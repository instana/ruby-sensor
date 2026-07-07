# frozen_string_literal: true

# (c) Copyright IBM Corp. 2026

require_relative 'base_converter'
require 'opentelemetry/semconv/db'
require 'opentelemetry/semconv/server'

module Instana
  module Exporter
    module Otlp
      # Converter for database spans to OTLP format
      class DatabaseConverter < BaseConverter
        def convert_attributes
          attributes = {}
          data = span[:data] || {}

          convert_activerecord_attributes(attributes, data[:activerecord])
          convert_sequel_attributes(attributes, data[:sequel])
          convert_redis_attributes(attributes, data[:redis])
          convert_memcache_attributes(attributes, data[:memcache])
          convert_mongo_attributes(attributes, data[:mongo])

          attributes
        end

        # Build OTel-compliant span name for database spans
        #
        # Formulas per SPAN_NAME_PATTERNS.txt Section 2:
        #   activerecord / sequel  → "{adapter} {db}"       e.g. "mysql2 myapp"
        #   redis                  → "redis {command}"       e.g. "redis GET"
        #   memcache               → "memcached {command}"   e.g. "memcached get"
        #   mongo                  → "{namespace}.{command}" e.g. "users.find"
        #
        # @return [String] The span name
        def span_name
          data = span[:data] || {}
          activerecord_span_name(data[:activerecord]) ||
            sequel_span_name(data[:sequel]) ||
            redis_span_name(data[:redis]) ||
            memcache_span_name(data[:memcache]) ||
            mongo_span_name(data[:mongo]) ||
            super
        end

        private

        def activerecord_span_name(ar_data)
          return unless ar_data

          parts = [ar_data[:adapter], ar_data[:db]].compact.reject(&:empty?)
          parts.empty? ? 'activerecord' : parts.join(' ')
        end

        def sequel_span_name(seq)
          return unless seq

          parts = [seq[:adapter], seq[:db]].compact.reject(&:empty?)
          parts.empty? ? 'sequel' : parts.join(' ')
        end

        def redis_span_name(redis)
          return unless redis

          cmd = redis[:command].to_s.strip
          cmd.empty? ? 'redis' : "redis #{cmd}"
        end

        def memcache_span_name(mc_data)
          return unless mc_data

          cmd = mc_data[:command].to_s.strip
          cmd.empty? ? 'memcached' : "memcached #{cmd}"
        end

        def mongo_span_name(mongo)
          return unless mongo

          ns  = mongo[:namespace].to_s.strip
          cmd = mongo[:command].to_s.strip
          parts = [ns, cmd].reject(&:empty?)
          parts.empty? ? 'mongodb' : parts.join('.')
        end

        def convert_activerecord_attributes(attributes, ar_data)
          return unless ar_data

          add_attribute(attributes, OpenTelemetry::SemConv::DB::DB_SYSTEM_NAME, ar_data[:adapter])
          add_attribute(attributes, OpenTelemetry::SemConv::DB::DB_NAMESPACE, ar_data[:db])
          add_attribute(attributes, OpenTelemetry::SemConv::DB::DB_QUERY_TEXT, ar_data[:sql])
          add_attribute(attributes, OpenTelemetry::SemConv::Incubating::DB::DB_USER, ar_data[:username])
          add_attribute(attributes, OpenTelemetry::SemConv::SERVER::SERVER_ADDRESS, ar_data[:host])
        end

        def convert_sequel_attributes(attributes, seq_data)
          return unless seq_data

          add_attribute(attributes, OpenTelemetry::SemConv::DB::DB_SYSTEM_NAME, seq_data[:adapter])
          add_attribute(attributes, OpenTelemetry::SemConv::DB::DB_NAMESPACE, seq_data[:db])
          add_attribute(attributes, OpenTelemetry::SemConv::DB::DB_QUERY_TEXT, seq_data[:sql])
          add_attribute(attributes, OpenTelemetry::SemConv::Incubating::DB::DB_USER, seq_data[:username])
          add_attribute(attributes, OpenTelemetry::SemConv::SERVER::SERVER_ADDRESS, seq_data[:host])
        end

        def convert_redis_attributes(attributes, redis_data)
          return unless redis_data

          add_attribute(attributes, OpenTelemetry::SemConv::DB::DB_SYSTEM_NAME, 'redis')
          add_attribute(attributes, OpenTelemetry::SemConv::DB::DB_QUERY_TEXT, redis_data[:command])
          add_attribute(attributes, 'db.redis.database_index', redis_data[:db])
          add_attribute(attributes, OpenTelemetry::SemConv::SERVER::SERVER_ADDRESS, extract_host(redis_data[:connection]))
          add_attribute(attributes, OpenTelemetry::SemConv::SERVER::SERVER_PORT, extract_port(redis_data[:connection]))
        end

        def convert_memcache_attributes(attributes, mc_data)
          return unless mc_data

          add_attribute(attributes, OpenTelemetry::SemConv::DB::DB_SYSTEM_NAME, 'memcached')
          add_attribute(attributes, OpenTelemetry::SemConv::DB::DB_OPERATION_NAME, mc_data[:command])
          add_attribute(attributes, 'db.memcached.key', mc_data[:key])
          add_attribute(attributes, 'db.memcached.keys', mc_data[:keys])
          add_attribute(attributes, 'db.memcached.namespace', mc_data[:namespace])
          add_attribute(attributes, OpenTelemetry::SemConv::SERVER::SERVER_ADDRESS, extract_host(mc_data[:server]))
          add_attribute(attributes, OpenTelemetry::SemConv::SERVER::SERVER_PORT, extract_port(mc_data[:server]))
        end

        def convert_mongo_attributes(attributes, mongo_data)
          return unless mongo_data

          add_attribute(attributes, OpenTelemetry::SemConv::DB::DB_SYSTEM_NAME, 'mongodb')
          add_attribute(attributes, OpenTelemetry::SemConv::DB::DB_NAMESPACE, mongo_data[:namespace])
          add_attribute(attributes, OpenTelemetry::SemConv::DB::DB_OPERATION_NAME, mongo_data[:command])
          add_attribute(attributes, OpenTelemetry::SemConv::DB::DB_QUERY_TEXT, mongo_data[:json])
          add_attribute(attributes, OpenTelemetry::SemConv::SERVER::SERVER_ADDRESS, mongo_data.dig(:peer, :hostname))
          add_attribute(attributes, OpenTelemetry::SemConv::SERVER::SERVER_PORT, mongo_data.dig(:peer, :port))
        end

        def extract_host(connection)
          return nil unless connection

          connection.to_s.split(':').first
        end

        def extract_port(connection)
          return nil unless connection

          port = connection.to_s.split(':').last
          port.to_i if port =~ /^\d+$/
        end
      end
    end
  end
end
