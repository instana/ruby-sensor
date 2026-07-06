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

          if (sqs = data[:sqs])
            queue = sqs[:queue].to_s.strip
            operation = sqs[:type].to_s =~ /^(delete|receive)/ ? 'receive' : 'publish'
            return queue.empty? ? "SQS #{operation}" : "#{queue} #{operation}"
          end

          if (sns = data[:sns])
            topic = sns[:topic].to_s.strip
            topic = sns[:target].to_s.strip if topic.empty?
            return topic.empty? ? 'SNS publish' : "#{topic} publish"
          end

          if (ddb = data[:dynamodb])
            op = ddb[:op].to_s.strip
            return op.empty? ? 'DynamoDB' : "DynamoDB.#{op}"
          end

          if (s3 = data[:s3])
            op = s3[:op].to_s.strip
            return op.empty? ? 'S3' : "S3.#{op}"
          end

          lambda_data = data.dig(:aws, :lambda, :invoke)
          if lambda_data
            fn = lambda_data[:function].to_s.strip
            return fn.empty? ? 'Lambda.invoke' : "Lambda.#{fn}"
          end

          super
        end

        def convert_attributes
          attributes = {}

          # AWS SQS
          sqs_data = span[:data]&.[](:sqs)
          if sqs_data
            add_attribute(attributes, OpenTelemetry::SemConv::Incubating::MESSAGING::MESSAGING_SYSTEM, 'aws_sqs')
            add_attribute(attributes, OpenTelemetry::SemConv::Incubating::MESSAGING::MESSAGING_DESTINATION_NAME, sqs_data[:queue])
            add_attribute(attributes, 'messaging.aws.sqs.message_group_id', sqs_data[:group])
            add_attribute(attributes, OpenTelemetry::SemConv::Incubating::MESSAGING::MESSAGING_BATCH_MESSAGE_COUNT, sqs_data[:size])

            operation = case sqs_data[:type]
                        when /^send/, /^single\.sync/ then 'send'
                        when /^delete/ then 'process'
                        when /^create/, /^get/ then 'create'
                        else 'send'
                        end
            add_attribute(attributes, OpenTelemetry::SemConv::Incubating::MESSAGING::MESSAGING_OPERATION_TYPE, operation)
          end

          # AWS SNS
          sns_data = span[:data]&.[](:sns)
          if sns_data
            add_attribute(attributes, OpenTelemetry::SemConv::Incubating::MESSAGING::MESSAGING_SYSTEM, 'aws_sns')
            add_attribute(attributes, OpenTelemetry::SemConv::Incubating::MESSAGING::MESSAGING_DESTINATION_NAME, sns_data[:topic])
            add_attribute(attributes, 'messaging.aws.sns.target_arn', sns_data[:target])
            add_attribute(attributes, 'messaging.aws.sns.phone_number', sns_data[:phone])
            add_attribute(attributes, 'messaging.aws.sns.subject', sns_data[:subject])
            add_attribute(attributes, OpenTelemetry::SemConv::Incubating::MESSAGING::MESSAGING_OPERATION_TYPE, 'send')
          end

          # AWS DynamoDB
          dynamodb_data = span[:data]&.[](:dynamodb)
          if dynamodb_data
            add_attribute(attributes, OpenTelemetry::SemConv::DB::DB_SYSTEM_NAME, 'dynamodb')
            add_attribute(attributes, OpenTelemetry::SemConv::DB::DB_OPERATION_NAME, dynamodb_data[:op])
            add_attribute(attributes, OpenTelemetry::SemConv::DB::DB_NAMESPACE, dynamodb_data[:table])
            add_attribute(attributes, 'aws.dynamodb.table_name', dynamodb_data[:table])
          end

          # AWS S3
          s3_data = span[:data]&.[](:s3)
          if s3_data
            add_attribute(attributes, 'aws.service', 's3')
            add_attribute(attributes, 'aws.s3.bucket', s3_data[:bucket])
            add_attribute(attributes, 'aws.s3.key', s3_data[:key])
            add_attribute(attributes, 'aws.s3.operation', s3_data[:op])
          end

          # AWS Lambda
          lambda_data = span[:data]&.[](:aws)&.[](:lambda)&.[](:invoke)
          if lambda_data
            add_attribute(attributes, 'aws.service', 'lambda')
            add_attribute(attributes, 'aws.lambda.function_name', lambda_data[:function])
            add_attribute(attributes, 'aws.lambda.invocation_type', lambda_data[:type])
            add_attribute(attributes, 'faas.invoked_name', lambda_data[:function])
          end

          attributes
        end
      end
    end
  end
end
