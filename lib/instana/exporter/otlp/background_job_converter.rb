# frozen_string_literal: true

# (c) Copyright IBM Corp. 2026

require_relative 'base_converter'
require 'opentelemetry/semconv/incubating/messaging'
require 'opentelemetry/semconv/server'

module Instana
  module Exporter
    module Otlp
      class BackgroundJobConverter < BaseConverter
        def convert_attributes
          attributes = {}

          case span[:n].to_s
          when 'sidekiq-client'
            convert_job_attributes(attributes, span[:'sidekiq-client'] || span[:data]&.[](:'sidekiq-client'), 'sidekiq', 'publish')
          when 'sidekiq-worker'
            convert_job_attributes(attributes, span[:'sidekiq-worker'] || span[:data]&.[](:'sidekiq-worker'), 'sidekiq', 'process')
          when 'resque-client'
            convert_job_attributes(attributes, span[:'resque-client'] || span[:data]&.[](:'resque-client'), 'resque', 'publish')
          when 'resque-worker'
            convert_job_attributes(attributes, span[:'resque-worker'] || span[:data]&.[](:'resque-worker'), 'resque', 'process')
          end

          attributes
        end

        private

        def convert_job_attributes(attributes, data, system, operation)
          return unless data

          add_attribute(attributes, OpenTelemetry::SemConv::Incubating::MESSAGING::MESSAGING_SYSTEM, system)
          add_attribute(attributes, OpenTelemetry::SemConv::Incubating::MESSAGING::MESSAGING_DESTINATION_NAME, data[:queue] || data['queue'])
          add_attribute(attributes, OpenTelemetry::SemConv::Incubating::MESSAGING::MESSAGING_OPERATION, operation)
          add_attribute(attributes, OpenTelemetry::SemConv::Incubating::MESSAGING::MESSAGING_MESSAGE_ID, data[:job_id] || data['job_id'])
          add_attribute(attributes, OpenTelemetry::SemConv::Incubating::MESSAGING::MESSAGING_CONSUMER_GROUP_NAME, data[:job] || data['job'])
          add_attribute(attributes, OpenTelemetry::SemConv::SERVER::SERVER_ADDRESS, extract_host(data[:'redis-url'] || data['redis-url']))
          add_attribute(attributes, OpenTelemetry::SemConv::SERVER::SERVER_PORT, extract_port(data[:'redis-url'] || data['redis-url']))
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
