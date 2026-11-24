# frozen_string_literal: true

# (c) Copyright IBM Corp. 2026

require_relative 'base_converter'
require 'opentelemetry/semconv/incubating/messaging'
require 'opentelemetry/semconv/server'

module Instana
  module Exporter
    module Otlp
      class BackgroundJobConverter < BaseConverter
        # Build OTel-compliant span name for background-job spans
        #
        # Formula per SPAN_NAME_PATTERNS.txt Section 3 (sidekiq / resque / activejob):
        #   sidekiq client → "{queue} publish"
        #   sidekiq worker → "{queue} consume"
        #   resque client  → "{queue} publish"
        #   resque worker  → "{queue} process"
        #   activejob      → "{queue} {action}"
        #
        # @return [String] The span name
        def span_name
          span_type = span[:n].to_s
          data_key  = span_type.to_sym
          job_data  = span[data_key] || span[:data]&.[](data_key) || {}

          queue = job_data[:queue] || job_data['queue']
          queue = queue.to_s.strip

          operation = case span_type
                      when 'sidekiq-client', 'resque-client'
                        'publish'
                      when 'sidekiq-worker'
                        'consume'
                      when 'resque-worker'
                        'process'
                      when 'activejob'
                        job_data[:action] || job_data['action'] || 'process'
                      else
                        'process'
                      end

          queue.empty? ? operation : "#{queue} #{operation}"
        end

        def convert_attributes
          attributes = {}
          span_type  = span[:n].to_s

          case span_type
          when 'sidekiq-client'
            convert_job_attributes(attributes, span[:'sidekiq-client'] || span[:data]&.[](:'sidekiq-client'), 'sidekiq', 'publish', 'send')
          when 'sidekiq-worker'
            convert_job_attributes(attributes, span[:'sidekiq-worker'] || span[:data]&.[](:'sidekiq-worker'), 'sidekiq', 'consume', 'process')
          when 'resque-client'
            convert_job_attributes(attributes, span[:'resque-client'] || span[:data]&.[](:'resque-client'), 'resque', 'publish', 'send')
          when 'resque-worker'
            convert_job_attributes(attributes, span[:'resque-worker'] || span[:data]&.[](:'resque-worker'), 'resque', 'process', 'process')
          when 'activejob'
            convert_activejob_attributes(attributes, span[:activejob] || span[:data]&.[](:activejob))
          end

          attributes
        end

        private

        def convert_job_attributes(attributes, data, system, operation_name, operation_type)
          return unless data

          add_attribute(attributes, OpenTelemetry::SemConv::Incubating::MESSAGING::MESSAGING_SYSTEM, system)
          add_attribute(attributes, OpenTelemetry::SemConv::Incubating::MESSAGING::MESSAGING_DESTINATION_NAME, data[:queue] || data['queue'])
          add_attribute(attributes, OpenTelemetry::SemConv::Incubating::MESSAGING::MESSAGING_OPERATION_NAME, operation_name)
          add_attribute(attributes, OpenTelemetry::SemConv::Incubating::MESSAGING::MESSAGING_OPERATION_TYPE, operation_type)
          add_attribute(attributes, OpenTelemetry::SemConv::Incubating::MESSAGING::MESSAGING_MESSAGE_ID, data[:job_id] || data['job_id']) unless system == 'resque'
          add_attribute(attributes, OpenTelemetry::SemConv::SERVER::SERVER_ADDRESS, extract_host(data[:'redis-url'] || data['redis-url']))
          add_attribute(attributes, OpenTelemetry::SemConv::SERVER::SERVER_PORT, extract_port(data[:'redis-url'] || data['redis-url']))
        end

        def convert_activejob_attributes(attributes, data)
          return unless data

          action = data[:action] || data['action'] || 'perform'
          operation_type = action.to_s == 'perform' ? 'process' : 'send'

          add_attribute(attributes, OpenTelemetry::SemConv::Incubating::MESSAGING::MESSAGING_SYSTEM, 'activejob')
          add_attribute(attributes, OpenTelemetry::SemConv::Incubating::MESSAGING::MESSAGING_DESTINATION_NAME, data[:queue] || data['queue'])
          add_attribute(attributes, OpenTelemetry::SemConv::Incubating::MESSAGING::MESSAGING_OPERATION_NAME, action)
          add_attribute(attributes, OpenTelemetry::SemConv::Incubating::MESSAGING::MESSAGING_OPERATION_TYPE, operation_type)
          add_attribute(attributes, OpenTelemetry::SemConv::Incubating::MESSAGING::MESSAGING_MESSAGE_ID, data[:job_id] || data['job_id'])
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
