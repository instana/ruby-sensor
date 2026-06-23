# frozen_string_literal: true

# (c) Copyright IBM Corp. 2026

require_relative 'base_converter'
require 'opentelemetry/semconv/db'
require 'opentelemetry/semconv/db'
require 'opentelemetry/semconv/server'

module Instana
  module Exporter
    module Otlp
      # Converter for database spans to OTLP format
      class DatabaseConverter < BaseConverter
        def convert_attributes
          attributes = {}
          Instana.logger.info("inside database converter")
          # ActiveRecord
          ar_data = span[:data]&.[](:activerecord)
          if ar_data
            add_attribute(attributes, OpenTelemetry::SemConv::DB::DB_SYSTEM_NAME, ar_data[:adapter])
            add_attribute(attributes, OpenTelemetry::SemConv::DB::DB_NAMESPACE, ar_data[:db])
            add_attribute(attributes, OpenTelemetry::SemConv::DB::DB_QUERY_TEXT, ar_data[:sql])
            add_attribute(attributes, OpenTelemetry::SemConv::Incubating::DB::DB_USER, ar_data[:username])
            add_attribute(attributes, OpenTelemetry::SemConv::SERVER::SERVER_ADDRESS, ar_data[:host])
          end

          # Sequel
          seq_data = span[:data]&.[](:sequel)
          if seq_data
            add_attribute(attributes, OpenTelemetry::SemConv::DB::DB_SYSTEM_NAME, seq_data[:adapter])
            add_attribute(attributes, OpenTelemetry::SemConv::DB::DB_NAMESPACE, seq_data[:db])
            add_attribute(attributes, OpenTelemetry::SemConv::DB::DB_QUERY_TEXT, seq_data[:sql])
            add_attribute(attributes, OpenTelemetry::SemConv::Incubating::DB::DB_USER, seq_data[:username])
            add_attribute(attributes, OpenTelemetry::SemConv::SERVER::SERVER_ADDRESS, seq_data[:host])
          end

          # Redis
          redis_data = span[:data]&.[](:redis)
          if redis_data
            add_attribute(attributes, OpenTelemetry::SemConv::DB::DB_SYSTEM_NAME, 'redis')
            add_attribute(attributes, OpenTelemetry::SemConv::DB::DB_QUERY_TEXT, redis_data[:command])
            add_attribute(attributes, 'db.redis.database_index', redis_data[:db])
            add_attribute(attributes, OpenTelemetry::SemConv::SERVER::SERVER_ADDRESS, extract_host(redis_data[:connection]))
            add_attribute(attributes, OpenTelemetry::SemConv::SERVER::SERVER_PORT, extract_port(redis_data[:connection]))
          end

          # Memcache (Dalli)
          mc_data = span[:data]&.[](:memcache)
          if mc_data
            add_attribute(attributes, OpenTelemetry::SemConv::DB::DB_SYSTEM_NAME, 'memcached')
            add_attribute(attributes, OpenTelemetry::SemConv::DB::DB_OPERATION_NAME, mc_data[:command])
            add_attribute(attributes, 'db.memcached.key', mc_data[:key])
            add_attribute(attributes, 'db.memcached.keys', mc_data[:keys])
            add_attribute(attributes, 'db.memcached.namespace', mc_data[:namespace])
            add_attribute(attributes, OpenTelemetry::SemConv::SERVER::SERVER_ADDRESS, extract_host(mc_data[:server]))
            add_attribute(attributes, OpenTelemetry::SemConv::SERVER::SERVER_PORT, extract_port(mc_data[:server]))
          end

          # MongoDB
          mongo_data = span[:data]&.[](:mongo)
          if mongo_data
            add_attribute(attributes, OpenTelemetry::SemConv::DB::DB_SYSTEM_NAME, 'mongodb')
            add_attribute(attributes, OpenTelemetry::SemConv::DB::DB_NAMESPACE, mongo_data[:namespace])
            add_attribute(attributes, OpenTelemetry::SemConv::DB::DB_OPERATION_NAME, mongo_data[:command])
            add_attribute(attributes, OpenTelemetry::SemConv::DB::DB_QUERY_TEXT, mongo_data[:json])
            add_attribute(attributes, OpenTelemetry::SemConv::SERVER::SERVER_ADDRESS, mongo_data.dig(:peer, :hostname))
            add_attribute(attributes, OpenTelemetry::SemConv::SERVER::SERVER_PORT, mongo_data.dig(:peer, :port))
          end

          attributes
        end

        private

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
