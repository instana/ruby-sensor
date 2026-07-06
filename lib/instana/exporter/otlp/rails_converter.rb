# frozen_string_literal: true

# (c) Copyright IBM Corp. 2026

require_relative 'base_converter'
require 'opentelemetry/semconv/incubating/code'

module Instana
  module Exporter
    module Otlp
      # Converter for Rails-related spans (ActionController, ActionView, ActionMailer) to OTLP format
      class RailsConverter < BaseConverter
        # Build OTel-compliant span name for Rails spans
        #
        # Formulas per SPAN_NAME_PATTERNS.txt Sections 5 & 7:
        #   actioncontroller  → "{Controller}#{action}"    e.g. "UsersController#index"
        #   actionview        → "{view_name}"              e.g. "users/index"
        #   render            → "{type} {name}"            e.g. "template users/index"
        #   mail.actionmailer → "{Class}#{method}"         e.g. "UserMailer#welcome_email"
        #
        # @return [String] The span name
        def span_name # rubocop:disable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
          case span[:n].to_s
          when 'actioncontroller'
            d = span[:data]&.[](:actioncontroller) || span[:actioncontroller] || {}
            ctrl   = d[:controller].to_s.strip
            action = d[:action].to_s.strip
            parts  = [ctrl, action].reject(&:empty?)
            parts.empty? ? 'actioncontroller' : parts.join('#')
          when 'actionview'
            d = span[:data]&.[](:actionview) || span[:actionview] || {}
            d[:name].to_s.strip.then { |n| n.empty? ? 'actionview' : n }
          when 'render'
            d = span[:data]&.[](:render) || span[:render] || {}
            type = d[:type].to_s.strip
            name = d[:name].to_s.strip
            parts = [type, name].reject(&:empty?)
            parts.empty? ? 'render' : parts.join(' ')
          when 'mail.actionmailer'
            d = span[:data]&.[](:actionmailer) || span[:actionmailer] || {}
            klass  = d[:class].to_s.strip
            method = d[:method].to_s.strip
            parts  = [klass, method].reject(&:empty?)
            parts.empty? ? 'mail.actionmailer' : parts.join('#')
          else
            super
          end
        end

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
