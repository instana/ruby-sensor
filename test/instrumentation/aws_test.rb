# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2021

require 'test_helper'

class AwsTest < Minitest::Test
  def setup
    clear_all!
  end

  def test_dynamodb_config_defaults
    assert ::Instana.config[:aws_dynamodb].is_a?(Hash)
    assert ::Instana.config[:aws_dynamodb].key?(:enabled)
    assert_equal true, ::Instana.config[:aws_dynamodb][:enabled]
  end

  def test_dynamo_db
    dynamo = Aws::DynamoDB::Client.new(
      region: "local",
      access_key_id: "placeholder",
      secret_access_key: "placeholder",
      endpoint: "http://localhost:8000"
    )

    assert_raises Aws::DynamoDB::Errors::ResourceNotFoundException do
      Instana::Tracer.start_or_continue_trace(:dynamo_test, {}) do
        dynamo.get_item(
          table_name: 'sample_table',
          key: { s: 'sample_item' }
        )
      end
    end

    spans = ::Instana.processor.queued_spans
    dynamo_span, entry_span, *rest = spans

    assert rest.empty?
    assert_equal entry_span[:s], dynamo_span[:p]
    assert_equal :dynamodb, dynamo_span[:n]
    assert_equal 'get', dynamo_span[:data][:dynamodb][:op]
    assert_equal 'sample_table', dynamo_span[:data][:dynamodb][:table]
  end

  def test_s3_config_defaults
    assert ::Instana.config[:aws_s3].is_a?(Hash)
    assert ::Instana.config[:aws_s3].key?(:enabled)
    assert_equal true, ::Instana.config[:aws_dynamodb][:enabled]
  end

  def test_s3
    s3_client = Aws::S3::Client.new(
      region: "local",
      access_key_id: "minioadmin",
      secret_access_key: "minioadmin",
      force_path_style: "true",
      endpoint: "http://localhost:9000"
    )

    assert_raises Aws::S3::Errors::NoSuchBucket do
      Instana::Tracer.start_or_continue_trace(:s3_test, {}) do
        s3_client.get_object(
          bucket: 'sample-bucket',
          key: 'sample_key'
        )
      end
    end

    spans = ::Instana.processor.queued_spans
    s3_span, entry_span, *rest = spans

    assert rest.empty?
    assert_equal entry_span[:s], s3_span[:p]
    assert_equal :s3, s3_span[:n]
    assert_equal 'get', s3_span[:data][:s3][:op]
    assert_equal 'sample-bucket', s3_span[:data][:s3][:bucket]
    assert_equal 'sample_key', s3_span[:data][:s3][:key]
  end

  def test_sns_config_defaults
    assert ::Instana.config[:aws_sns].is_a?(Hash)
    assert ::Instana.config[:aws_sns].key?(:enabled)
    assert_equal true, ::Instana.config[:aws_sns][:enabled]
  end

  def test_sns_publish
    sns = Aws::SNS::Client.new(
      region: "local",
      access_key_id: "test",
      secret_access_key: "test",
      endpoint: "http://localhost:9911"
    )

    assert_raises Aws::SNS::Errors::NotFound do
      Instana::Tracer.start_or_continue_trace(:sns_test, {}) do
        sns.publish(
          topic_arn: 'topic:arn',
          target_arn: 'target:arn',
          phone_number: '555-0100',
          subject: 'Test Subject',
          message: 'Test Message'
        )
      end
    end

    spans = ::Instana.processor.queued_spans
    aws_span, entry_span, *rest = spans

    assert rest.empty?
    assert_equal entry_span[:s], aws_span[:p]
    assert_equal :sns, aws_span[:n]
    assert_equal 'topic:arn', aws_span[:data][:sns][:topic]
    assert_equal 'target:arn', aws_span[:data][:sns][:target]
    assert_equal '555-0100', aws_span[:data][:sns][:phone]
    assert_equal 'Test Subject', aws_span[:data][:sns][:subject]
  end

  def test_sns_other
    sns = Aws::SNS::Client.new(
      region: "local",
      access_key_id: "test",
      secret_access_key: "test",
      endpoint: "http://localhost:9911"
    )

    Instana::Tracer.start_or_continue_trace(:sns_test, {}) do
      sns.list_subscriptions
    end

    spans = ::Instana.processor.queued_spans
    aws_span, entry_span, *rest = spans

    assert rest.empty?
    assert_equal entry_span[:s], aws_span[:p]
    assert_equal :"net-http", aws_span[:n]
  end

  def test_sqs_config_defaults
    assert ::Instana.config[:aws_sqs].is_a?(Hash)
    assert ::Instana.config[:aws_sqs].key?(:enabled)
    assert_equal true, ::Instana.config[:aws_sqs][:enabled]
  end

  def test_sqs
    sqs = Aws::SQS::Client.new(
      region: "local",
      access_key_id: "test",
      secret_access_key: "test",
      endpoint: "http://localhost:9324"
    )

    create_response = nil
    get_url_response = nil

    Instana::Tracer.start_or_continue_trace(:sqs_test, {}) do
      create_response = sqs.create_queue(queue_name: 'test')
      get_url_response = sqs.get_queue_url(queue_name: 'test')
      sqs.send_message(queue_url: create_response.queue_url, message_body: 'Sample')
    end

    received = sqs.receive_message(
      queue_url: create_response.queue_url,
      message_attribute_names: ['All']
    )
    sqs.delete_queue(queue_url: create_response.queue_url)
    message = received.messages.first
    create_span, get_span, send_span, _root = ::Instana.processor.queued_spans

    assert_equal :sqs, create_span[:n]
    assert_equal create_response.queue_url, create_span[:data][:sqs][:queue]
    assert_equal 'exit', create_span[:data][:sqs][:sort]
    assert_equal 'create.queue', create_span[:data][:sqs][:type]

    assert_equal :sqs, get_span[:n]
    assert_equal get_url_response.queue_url, get_span[:data][:sqs][:queue]
    assert_equal 'exit', get_span[:data][:sqs][:sort]
    assert_equal 'get.queue', get_span[:data][:sqs][:type]

    assert_equal :sqs, send_span[:n]
    assert_equal get_url_response.queue_url, send_span[:data][:sqs][:queue]
    assert_equal 'exit', send_span[:data][:sqs][:sort]
    assert_equal 'single.sync', send_span[:data][:sqs][:type]
    assert_equal send_span[:t], message.message_attributes['X_INSTANA_T'].string_value
    assert_equal send_span[:s], message.message_attributes['X_INSTANA_S'].string_value
    assert_equal 'Sample', message.body
  end

  def test_lambda_config_defaults
    assert ::Instana.config[:aws_lambda].is_a?(Hash)
    assert ::Instana.config[:aws_lambda].key?(:enabled)
    assert_equal true, ::Instana.config[:aws_lambda][:enabled]
  end

  def test_lambda
    stub_request(:post, "https://lambda.local.amazonaws.com/2015-03-31/functions/Test/invocations")
      .with(
        body: "data",
        headers: {
          'X-Amz-Client-Context' => /.+/
        }
      )
      .to_return(status: 200, body: "", headers: {})

    lambda = Aws::Lambda::Client.new(
      endpoint: 'https://lambda.local.amazonaws.com',
      region: 'local',
      access_key_id: "test",
      secret_access_key: "test"
    )

    Instana::Tracer.start_or_continue_trace(:lambda_test, {}) do
      lambda.invoke(
        function_name: 'Test',
        invocation_type: 'Event',
        payload: 'data'
      )
    end

    spans = ::Instana.processor.queued_spans
    lambda_span, _entry_span, *rest = spans

    assert rest.empty?

    assert_equal :"aws.lambda.invoke", lambda_span[:n]
    assert_equal 'Test', lambda_span[:data][:aws][:lambda][:invoke][:function]
    assert_equal 'Event', lambda_span[:data][:aws][:lambda][:invoke][:type]
  end
end
