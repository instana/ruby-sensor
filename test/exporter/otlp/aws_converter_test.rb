# frozen_string_literal: true

# (c) Copyright IBM Corp. 2026

require 'test_helper'
require 'instana/exporter/otlp/aws_converter'

class AwsConverterTest < Minitest::Test # rubocop:disable Metrics/ClassLength
  # AWS SQS Tests
  def test_sqs_send_operation_conversion
    span = create_span('aws.sqs', {
                         sqs: { queue: 'my-queue', group: 'group-1', size: 5, type: 'send' }
                       })
    converter = Instana::Exporter::Otlp::AwsConverter.new(span)
    attrs = converter.send(:convert_attributes)

    assert_equal 'aws_sqs', attrs['messaging.system']
    assert_equal 'my-queue', attrs['messaging.destination.name']
    assert_equal 'group-1', attrs['messaging.aws.sqs.message_group_id']
    assert_equal 5, attrs['messaging.batch.message_count']
    assert_equal 'send', attrs['messaging.operation.type']
  end

  def test_sqs_single_sync_operation_conversion
    span = create_span('aws.sqs', {
                         sqs: { queue: 'test-queue', type: 'single.sync' }
                       })
    converter = Instana::Exporter::Otlp::AwsConverter.new(span)
    attrs = converter.send(:convert_attributes)

    assert_equal 'aws_sqs', attrs['messaging.system']
    assert_equal 'test-queue', attrs['messaging.destination.name']
    assert_equal 'send', attrs['messaging.operation.type']
  end

  def test_sqs_delete_operation_conversion
    span = create_span('aws.sqs', {
                         sqs: { queue: 'delete-queue', type: 'delete' }
                       })
    converter = Instana::Exporter::Otlp::AwsConverter.new(span)
    attrs = converter.send(:convert_attributes)

    assert_equal 'aws_sqs', attrs['messaging.system']
    assert_equal 'delete-queue', attrs['messaging.destination.name']
    assert_equal 'process', attrs['messaging.operation.type']
  end

  def test_sqs_create_operation_conversion
    span = create_span('aws.sqs', {
                         sqs: { queue: 'new-queue', type: 'create' }
                       })
    converter = Instana::Exporter::Otlp::AwsConverter.new(span)
    attrs = converter.send(:convert_attributes)

    assert_equal 'aws_sqs', attrs['messaging.system']
    assert_equal 'new-queue', attrs['messaging.destination.name']
    assert_equal 'create', attrs['messaging.operation.type']
  end

  def test_sqs_get_operation_conversion
    span = create_span('aws.sqs', {
                         sqs: { queue: 'get-queue', type: 'get' }
                       })
    converter = Instana::Exporter::Otlp::AwsConverter.new(span)
    attrs = converter.send(:convert_attributes)

    assert_equal 'aws_sqs', attrs['messaging.system']
    assert_equal 'get-queue', attrs['messaging.destination.name']
    assert_equal 'create', attrs['messaging.operation.type']
  end

  def test_sqs_unknown_operation_defaults_to_send
    span = create_span('aws.sqs', {
                         sqs: { queue: 'unknown-queue', type: 'unknown_operation' }
                       })
    converter = Instana::Exporter::Otlp::AwsConverter.new(span)
    attrs = converter.send(:convert_attributes)

    assert_equal 'send', attrs['messaging.operation.type']
  end

  def test_sqs_with_nil_values
    span = create_span('aws.sqs', {
                         sqs: { queue: 'test-queue', group: nil, size: nil, type: 'send' }
                       })
    converter = Instana::Exporter::Otlp::AwsConverter.new(span)
    attrs = converter.send(:convert_attributes)

    assert_equal 'aws_sqs', attrs['messaging.system']
    assert_equal 'test-queue', attrs['messaging.destination.name']
    assert_nil attrs['messaging.aws.sqs.message_group_id']
    assert_nil attrs['messaging.batch.message_count']
  end

  # AWS SNS Tests
  def test_sns_basic_conversion
    span = create_span('aws.sns', {
                         sns: { topic: 'my-topic', target: 'arn:aws:sns:us-east-1:123456789:my-topic' }
                       })
    converter = Instana::Exporter::Otlp::AwsConverter.new(span)
    attrs = converter.send(:convert_attributes)

    assert_equal 'aws_sns', attrs['messaging.system']
    assert_equal 'my-topic', attrs['messaging.destination.name']
    assert_equal 'arn:aws:sns:us-east-1:123456789:my-topic', attrs['messaging.aws.sns.target_arn']
    assert_equal 'send', attrs['messaging.operation.type']
  end

  def test_sns_with_phone_number
    span = create_span('aws.sns', {
                         sns: { topic: 'sms-topic', phone: '+1234567890' }
                       })
    converter = Instana::Exporter::Otlp::AwsConverter.new(span)
    attrs = converter.send(:convert_attributes)

    assert_equal 'aws_sns', attrs['messaging.system']
    assert_equal '+1234567890', attrs['messaging.aws.sns.phone_number']
  end

  def test_sns_with_subject
    span = create_span('aws.sns', {
                         sns: { topic: 'notification-topic', subject: 'Important Alert' }
                       })
    converter = Instana::Exporter::Otlp::AwsConverter.new(span)
    attrs = converter.send(:convert_attributes)

    assert_equal 'aws_sns', attrs['messaging.system']
    assert_equal 'Important Alert', attrs['messaging.aws.sns.subject']
  end

  def test_sns_with_all_attributes
    span = create_span('aws.sns', {
                         sns: {
                           topic: 'full-topic',
                           target: 'arn:aws:sns:us-west-2:987654321:full-topic',
                           phone: '+9876543210',
                           subject: 'Test Subject'
                         }
                       })
    converter = Instana::Exporter::Otlp::AwsConverter.new(span)
    attrs = converter.send(:convert_attributes)

    assert_equal 'aws_sns', attrs['messaging.system']
    assert_equal 'full-topic', attrs['messaging.destination.name']
    assert_equal 'arn:aws:sns:us-west-2:987654321:full-topic', attrs['messaging.aws.sns.target_arn']
    assert_equal '+9876543210', attrs['messaging.aws.sns.phone_number']
    assert_equal 'Test Subject', attrs['messaging.aws.sns.subject']
    assert_equal 'send', attrs['messaging.operation.type']
  end

  # AWS DynamoDB Tests
  def test_dynamodb_basic_conversion
    span = create_span('aws.dynamodb', {
                         dynamodb: { op: 'GetItem', table: 'users-table' }
                       })
    converter = Instana::Exporter::Otlp::AwsConverter.new(span)
    attrs = converter.send(:convert_attributes)

    assert_equal 'dynamodb', attrs['db.system.name']
    assert_equal 'GetItem', attrs['db.operation.name']
    assert_equal 'users-table', attrs['db.namespace']
    assert_equal 'users-table', attrs['aws.dynamodb.table_name']
  end

  def test_dynamodb_put_item_operation
    span = create_span('aws.dynamodb', {
                         dynamodb: { op: 'PutItem', table: 'orders-table' }
                       })
    converter = Instana::Exporter::Otlp::AwsConverter.new(span)
    attrs = converter.send(:convert_attributes)

    assert_equal 'dynamodb', attrs['db.system.name']
    assert_equal 'PutItem', attrs['db.operation.name']
    assert_equal 'orders-table', attrs['db.namespace']
    assert_equal 'orders-table', attrs['aws.dynamodb.table_name']
  end

  def test_dynamodb_query_operation
    span = create_span('aws.dynamodb', {
                         dynamodb: { op: 'Query', table: 'products-table' }
                       })
    converter = Instana::Exporter::Otlp::AwsConverter.new(span)
    attrs = converter.send(:convert_attributes)

    assert_equal 'dynamodb', attrs['db.system.name']
    assert_equal 'Query', attrs['db.operation.name']
    assert_equal 'products-table', attrs['db.namespace']
  end

  def test_dynamodb_scan_operation
    span = create_span('aws.dynamodb', {
                         dynamodb: { op: 'Scan', table: 'analytics-table' }
                       })
    converter = Instana::Exporter::Otlp::AwsConverter.new(span)
    attrs = converter.send(:convert_attributes)

    assert_equal 'dynamodb', attrs['db.system.name']
    assert_equal 'Scan', attrs['db.operation.name']
    assert_equal 'analytics-table', attrs['db.namespace']
  end

  # AWS S3 Tests
  def test_s3_basic_conversion
    span = create_span('aws.s3', {
                         s3: { bucket: 'my-bucket', key: 'path/to/file.txt', op: 'GetObject' }
                       })
    converter = Instana::Exporter::Otlp::AwsConverter.new(span)
    attrs = converter.send(:convert_attributes)

    assert_equal 's3', attrs['aws.service']
    assert_equal 'my-bucket', attrs['aws.s3.bucket']
    assert_equal 'path/to/file.txt', attrs['aws.s3.key']
    assert_equal 'GetObject', attrs['aws.s3.operation']
  end

  def test_s3_put_object_operation
    span = create_span('aws.s3', {
                         s3: { bucket: 'uploads-bucket', key: 'uploads/image.jpg', op: 'PutObject' }
                       })
    converter = Instana::Exporter::Otlp::AwsConverter.new(span)
    attrs = converter.send(:convert_attributes)

    assert_equal 's3', attrs['aws.service']
    assert_equal 'uploads-bucket', attrs['aws.s3.bucket']
    assert_equal 'uploads/image.jpg', attrs['aws.s3.key']
    assert_equal 'PutObject', attrs['aws.s3.operation']
  end

  def test_s3_delete_object_operation
    span = create_span('aws.s3', {
                         s3: { bucket: 'temp-bucket', key: 'temp/file.tmp', op: 'DeleteObject' }
                       })
    converter = Instana::Exporter::Otlp::AwsConverter.new(span)
    attrs = converter.send(:convert_attributes)

    assert_equal 's3', attrs['aws.service']
    assert_equal 'temp-bucket', attrs['aws.s3.bucket']
    assert_equal 'temp/file.tmp', attrs['aws.s3.key']
    assert_equal 'DeleteObject', attrs['aws.s3.operation']
  end

  def test_s3_list_objects_operation
    span = create_span('aws.s3', {
                         s3: { bucket: 'data-bucket', op: 'ListObjects' }
                       })
    converter = Instana::Exporter::Otlp::AwsConverter.new(span)
    attrs = converter.send(:convert_attributes)

    assert_equal 's3', attrs['aws.service']
    assert_equal 'data-bucket', attrs['aws.s3.bucket']
    assert_nil attrs['aws.s3.key']
    assert_equal 'ListObjects', attrs['aws.s3.operation']
  end

  # AWS Lambda Tests
  def test_lambda_basic_conversion
    span = create_span('aws.lambda', {
                         aws: {
                           lambda: {
                             invoke: { function: 'my-function', type: 'RequestResponse' }
                           }
                         }
                       })
    converter = Instana::Exporter::Otlp::AwsConverter.new(span)
    attrs = converter.send(:convert_attributes)

    assert_equal 'lambda', attrs['aws.service']
    assert_equal 'my-function', attrs['aws.lambda.function_name']
    assert_equal 'RequestResponse', attrs['aws.lambda.invocation_type']
    assert_equal 'my-function', attrs['faas.invoked_name']
  end

  def test_lambda_event_invocation
    span = create_span('aws.lambda', {
                         aws: {
                           lambda: {
                             invoke: { function: 'async-function', type: 'Event' }
                           }
                         }
                       })
    converter = Instana::Exporter::Otlp::AwsConverter.new(span)
    attrs = converter.send(:convert_attributes)

    assert_equal 'lambda', attrs['aws.service']
    assert_equal 'async-function', attrs['aws.lambda.function_name']
    assert_equal 'Event', attrs['aws.lambda.invocation_type']
    assert_equal 'async-function', attrs['faas.invoked_name']
  end

  def test_lambda_dry_run_invocation
    span = create_span('aws.lambda', {
                         aws: {
                           lambda: {
                             invoke: { function: 'test-function', type: 'DryRun' }
                           }
                         }
                       })
    converter = Instana::Exporter::Otlp::AwsConverter.new(span)
    attrs = converter.send(:convert_attributes)

    assert_equal 'lambda', attrs['aws.service']
    assert_equal 'test-function', attrs['aws.lambda.function_name']
    assert_equal 'DryRun', attrs['aws.lambda.invocation_type']
  end

  # Edge Cases and Mixed Tests
  def test_empty_span_data
    span = create_span('aws.unknown', {})
    converter = Instana::Exporter::Otlp::AwsConverter.new(span)
    attrs = converter.send(:convert_attributes)

    assert_empty attrs
  end

  def test_nil_span_data
    span = Instana::Span.new('aws.test'.to_sym)
    span[:data] = nil
    span.close
    converter = Instana::Exporter::Otlp::AwsConverter.new(span)
    attrs = converter.send(:convert_attributes)

    assert_empty attrs
  end

  def test_multiple_aws_services_in_same_span
    # This shouldn't happen in practice, but test defensive coding
    span = create_span('aws.mixed', {
                         sqs: { queue: 'test-queue', type: 'send' },
                         sns: { topic: 'test-topic' }
                       })
    converter = Instana::Exporter::Otlp::AwsConverter.new(span)
    attrs = converter.send(:convert_attributes)

    # SNS overwrites SQS since both set messaging.system and messaging.destination.name
    # In practice, a span should only have one AWS service type
    assert_equal 'aws_sns', attrs['messaging.system']
    assert_equal 'test-topic', attrs['messaging.destination.name']
    assert_equal 'send', attrs['messaging.operation.type']
  end

  def test_converter_inherits_from_base_converter
    span = create_span('aws.sqs', { sqs: { queue: 'test' } })
    converter = Instana::Exporter::Otlp::AwsConverter.new(span)

    assert_kind_of Instana::Exporter::Otlp::BaseConverter, converter
  end

  def test_full_span_conversion_with_sqs
    span = create_span('aws.sqs', {
                         sqs: { queue: 'integration-queue', type: 'send', size: 10 }
                       })
    converter = Instana::Exporter::Otlp::AwsConverter.new(span)
    result = converter.convert

    # Verify base attributes are present
    assert result[:trace_id]
    assert result[:span_id]
    assert result[:name]
    assert result[:kind]
    assert result[:start_timestamp]
    assert result[:end_timestamp]
    assert result[:status]
    assert result[:attributes]

    # Verify AWS-specific attributes
    attrs = result[:attributes]
    assert_equal 'aws_sqs', attrs['messaging.system']
    assert_equal 'integration-queue', attrs['messaging.destination.name']
  end

  def test_full_span_conversion_with_dynamodb
    span = create_span('aws.dynamodb', {
                         dynamodb: { op: 'BatchGetItem', table: 'batch-table' }
                       })
    converter = Instana::Exporter::Otlp::AwsConverter.new(span)
    result = converter.convert

    # Verify base attributes are present
    assert result[:trace_id]
    assert result[:span_id]
    assert result[:attributes]

    # Verify DynamoDB-specific attributes
    attrs = result[:attributes]
    assert_equal 'dynamodb', attrs['db.system.name']
    assert_equal 'BatchGetItem', attrs['db.operation.name']
    assert_equal 'batch-table', attrs['db.namespace']
  end

  private

  def create_span(name, data)
    span = Instana::Span.new(name.to_sym)
    span[:data] = data
    span.close
    span
  end
end
