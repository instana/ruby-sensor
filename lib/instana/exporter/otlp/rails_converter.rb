# frozen_string_literal: true

# (c) Copyright IBM Corp. 2026

require_relative 'base_converter'
require 'opentelemetry/semconv/incubating/code'

module Instana
  module Exporter
    module Otlp
      # Converter for Rails-related spans (ActionController, ActionView, ActionMailer) to OTLP format
      class RailsConverter < BaseConverter
        def convert_attributes
          attributes = {}

          case span[:n].to_s
          when 'actioncontroller'
            convert_action_controller_attributes(attributes)
          when 'actionview'
            convert_action_view_attributes(attributes)
          when 'render'
            convert_render_attributes(attributes)
          when 'mail.actionmailer'
            convert_action_mailer_attributes(attributes)
          end

          attributes
        end

        private

        # Convert ActionController span attributes
        def convert_action_controller_attributes(attributes)
          controller_data = span[:data]&.[](:actioncontroller) || span[:actioncontroller]
          return unless controller_data

          add_attribute(attributes, OpenTelemetry::SemConv::Incubating::CODE::CODE_NAMESPACE, controller_data[:controller])
          add_attribute(attributes, OpenTelemetry::SemConv::Incubating::CODE::CODE_FUNCTION, controller_data[:action])
        end

        # Convert ActionView span attributes
        def convert_action_view_attributes(attributes)
          view_data = span[:data]&.[](:actionview) || span[:actionview]
          return unless view_data

          add_attribute(attributes, 'rails.view.name', view_data[:name])
        end

        # Convert render span attributes
        def convert_render_attributes(attributes)
          render_data = span[:data]&.[](:render) || span[:render]
          return unless render_data

          add_attribute(attributes, 'rails.render.type', render_data[:type])
          add_attribute(attributes, 'rails.render.name', render_data[:name])
        end

        # Convert ActionMailer span attributes
        def convert_action_mailer_attributes(attributes)
          mailer_data = span[:data]&.[](:actionmailer) || span[:actionmailer]
          return unless mailer_data

          add_attribute(attributes, OpenTelemetry::SemConv::Incubating::CODE::CODE_NAMESPACE, mailer_data[:class])
          add_attribute(attributes, OpenTelemetry::SemConv::Incubating::CODE::CODE_FUNCTION, mailer_data[:method])
        end
      end
    end
  end
end
