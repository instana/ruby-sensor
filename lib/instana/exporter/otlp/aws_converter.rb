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
