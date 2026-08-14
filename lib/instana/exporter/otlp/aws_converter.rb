# frozen_string_literal: true

# (c) Copyright IBM Corp. 2026

require_relative 'base_converter'
require 'opentelemetry/semconv/incubating/messaging'
require 'opentelemetry/semconv/db'
require 'opentelemetry/semconv/incubating/db'

module Instana
  module Exporter
    module Otlp
      # Converter for AWS SDK spans (SQS, SNS, DynamoDB) to OTLP format
      class AwsConverter < BaseConverter
        # Build OTel-compliant span name for AWS SDK spans
        #
        # Formulas per SPAN_NAME_PATTERNS.txt Section 6:
        #   SQS send/publish  → "{queue} publish"
        #   SQS receive/delete → "{queue} receive"
        #   SNS               → "{topic} publish"
        #   DynamoDB          → "DynamoDB.{op}"      e.g. "DynamoDB.PutItem"
        #   S3                → "S3.{op}"            e.g. "S3.PutObject"
        #   Lambda invoke     → "Lambda.{function}"
        #
        # @return [String] The span name
        def span_name
          data = span[:data] || {}
          sqs_span_name(data[:sqs]) ||
            sns_span_name(data[:sns]) ||
            dynamodb_span_name(data[:dynamodb]) ||
            s3_span_name(data[:s3]) ||
            lambda_span_name(data.dig(:aws, :lambda, :invoke)) ||
            super
        end

        def convert_attributes
          attributes = {}
          data = span[:data]
          return attributes unless data

          convert_sqs_attributes(attributes, data[:sqs])
          convert_sns_attributes(attributes, data[:sns])
          convert_dynamodb_attributes(attributes, data[:dynamodb])
          convert_s3_attributes(attributes, data[:s3])
          convert_lambda_attributes(attributes, data.dig(:aws, :lambda, :invoke))

          attributes
        end

        private

        def sqs_span_name(sqs)
          return unless sqs

          queue = sqs[:queue].to_s.strip
          operation = sqs[:type].to_s =~ /^(delete|receive)/ ? 'receive' : 'publish'
          queue.empty? ? "SQS #{operation}" : "#{queue} #{operation}"
        end

        def sns_span_name(sns)
          return unless sns

          topic = sns[:topic].to_s.strip
          topic = sns[:target].to_s.strip if topic.empty?
          topic.empty? ? 'SNS publish' : "#{topic} publish"
        end

        def dynamodb_span_name(ddb)
          return unless ddb

          op = ddb[:op].to_s.strip
          op.empty? ? 'DynamoDB' : "DynamoDB.#{op}"
        end

        def s3_span_name(s3_data)
          return unless s3_data

          op = s3_data[:op].to_s.strip
          op.empty? ? 'S3' : "S3.#{op}"
        end

        def lambda_span_name(lambda_data)
          return unless lambda_data

          fn = lambda_data[:function].to_s.strip
          fn.empty? ? 'Lambda.invoke' : "Lambda.#{fn}"
        end

        def convert_sqs_attributes(attributes, sqs_data)
          return unless sqs_data

          add_attribute(attributes, OpenTelemetry::SemConv::Incubating::MESSAGING::MESSAGING_SYSTEM, 'aws_sqs')
          add_attribute(attributes, OpenTelemetry::SemConv::Incubating::MESSAGING::MESSAGING_DESTINATION_NAME, sqs_data[:queue])
          add_attribute(attributes, 'messaging.aws.sqs.message_group_id', sqs_data[:group])
          add_attribute(attributes, OpenTelemetry::SemConv::Incubating::MESSAGING::MESSAGING_BATCH_MESSAGE_COUNT, sqs_data[:size])
          add_attribute(attributes, OpenTelemetry::SemConv::Incubating::MESSAGING::MESSAGING_OPERATION_TYPE, sqs_operation_type(sqs_data[:type]))
        end

        def sqs_operation_type(type)
          case type.to_s
          when /^send/, /^single\.sync/ then 'send'
          when /^delete/ then 'process'
          when /^create/, /^get/ then 'create'
          else 'send'
          end
        end

        def convert_sns_attributes(attributes, sns_data)
          return unless sns_data

          add_attribute(attributes, OpenTelemetry::SemConv::Incubating::MESSAGING::MESSAGING_SYSTEM, 'aws_sns')
          add_attribute(attributes, OpenTelemetry::SemConv::Incubating::MESSAGING::MESSAGING_DESTINATION_NAME, sns_data[:topic])
          add_attribute(attributes, 'messaging.aws.sns.target_arn', sns_data[:target])
          add_attribute(attributes, 'messaging.aws.sns.phone_number', sns_data[:phone])
          add_attribute(attributes, 'messaging.aws.sns.subject', sns_data[:subject])
          add_attribute(attributes, OpenTelemetry::SemConv::Incubating::MESSAGING::MESSAGING_OPERATION_TYPE, 'send')
        end

        def convert_dynamodb_attributes(attributes, dynamodb_data)
          return unless dynamodb_data

          add_attribute(attributes, OpenTelemetry::SemConv::DB::DB_SYSTEM_NAME, 'dynamodb')
          add_attribute(attributes, OpenTelemetry::SemConv::DB::DB_OPERATION_NAME, dynamodb_data[:op])
          add_attribute(attributes, OpenTelemetry::SemConv::DB::DB_NAMESPACE, dynamodb_data[:table])
          add_attribute(attributes, 'aws.dynamodb.table_name', dynamodb_data[:table])
        end

        def convert_s3_attributes(attributes, s3_data)
          return unless s3_data

          add_attribute(attributes, 'aws.service', 's3')
          add_attribute(attributes, 'aws.s3.bucket', s3_data[:bucket])
          add_attribute(attributes, 'aws.s3.key', s3_data[:key])
          add_attribute(attributes, 'aws.s3.operation', s3_data[:op])
        end

        def convert_lambda_attributes(attributes, lambda_data)
          return unless lambda_data

          add_attribute(attributes, 'aws.service', 'lambda')
          add_attribute(attributes, 'aws.lambda.function_name', lambda_data[:function])
          add_attribute(attributes, 'aws.lambda.invocation_type', lambda_data[:type])
          add_attribute(attributes, 'faas.invoked_name', lambda_data[:function])
        end
      end
    end
  end
end
