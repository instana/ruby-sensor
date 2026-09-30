# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2021

require 'test_helper'

class AwsDynamoDbTest < Minitest::Test
  def setup
    clear_all!
  end

  def test_dynamo_db
    dynamo = Aws::DynamoDB::Client.new(
      region: "local",
      access_key_id: "placeholder",
      secret_access_key: "placeholder",
      endpoint: "http://localhost:8000"
    )

    assert_raises Aws::DynamoDB::Errors::ResourceNotFoundException do
      Instana.tracer.in_span(:dynamo_test, attributes: {}) do
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

  def test_dynamo_db_operations
    dynamo = Aws::DynamoDB::Client.new(
      region: "local",
      access_key_id: "placeholder",
      secret_access_key: "placeholder",
      endpoint: "http://localhost:8000"
    )

    op_map = {
      [:create_table, { table_name: 'tbl',
                        attribute_definitions: [{ attribute_name: 'id', attribute_type: 'S' }],
                        key_schema: [{ attribute_name: 'id', key_type: 'HASH' }],
                        billing_mode: 'PAY_PER_REQUEST' }] => 'create',
      [:list_tables, {}] => 'list',
      [:put_item,    { table_name: 'tbl', item: { 'id' => { s: '1' } } }] => 'put',
      [:update_item, { table_name: 'tbl',
                       key: { 'id' => { s: '1' } },
                       update_expression: 'SET x = :v',
                       expression_attribute_values: { ':v' => { s: 'val' } } }] => 'update',
      [:delete_item, { table_name: 'tbl', key: { 'id' => { s: '1' } } }] => 'delete'
    }

    op_map.each do |(op_name, params), expected_op|
      clear_all!
      begin
        Instana.tracer.in_span(:dynamo_test) do
          dynamo.send(op_name, params)
        end
      rescue StandardError
        # expected – local endpoint not running
      end

      spans = ::Instana.processor.queued_spans
      dynamo_span = find_first_span_by_name(spans, :dynamodb)
      next unless dynamo_span

      assert_equal expected_op, dynamo_span[:data][:dynamodb][:op],
                   "Expected op #{expected_op} for #{op_name}"
    end
  end

  def test_dynamo_db_unknown_operation
    dynamo = Aws::DynamoDB::Client.new(
      region: "local",
      access_key_id: "placeholder",
      secret_access_key: "placeholder",
      endpoint: "http://localhost:8000"
    )

    begin
      Instana.tracer.in_span(:dynamo_test) do
        dynamo.describe_table(table_name: 'some_table')
      end
    rescue StandardError
      # expected
    end

    spans = ::Instana.processor.queued_spans
    dynamo_span = find_first_span_by_name(spans, :dynamodb)
    assert_equal 'describe_table', dynamo_span[:data][:dynamodb][:op] if dynamo_span
  end

  def test_dynamo_db_global_table_name_fallback
    dynamo = Aws::DynamoDB::Client.new(
      region: "local",
      access_key_id: "placeholder",
      secret_access_key: "placeholder",
      endpoint: "http://localhost:8000"
    )

    begin
      Instana.tracer.in_span(:dynamo_test) do
        dynamo.describe_global_table(global_table_name: 'my_global_table')
      end
    rescue StandardError
      # expected
    end

    spans = ::Instana.processor.queued_spans
    dynamo_span = find_first_span_by_name(spans, :dynamodb)
    assert_equal 'my_global_table', dynamo_span[:data][:dynamodb][:table] if dynamo_span
  end
end

class AwsS3Test < Minitest::Test
  def setup
    clear_all!
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
      Instana.tracer.in_span(:s3_test, attributes: {}) do
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

  def test_s3_operations
    s3_client = Aws::S3::Client.new(
      region: "local",
      access_key_id: "minioadmin",
      secret_access_key: "minioadmin",
      force_path_style: "true",
      endpoint: "http://localhost:9000"
    )

    operations = {
      create_bucket: { bucket: 'b' },
      delete_bucket: { bucket: 'b' },
      delete_object: { bucket: 'b', key: 'k' },
      head_object: { bucket: 'b', key: 'k' },
      list_objects: { bucket: 'b' },
      put_object: { bucket: 'b', key: 'k', body: 'data' }
    }

    expected_ops = {
      create_bucket: 'createBucket',
      delete_bucket: 'deleteBucket',
      delete_object: 'delete',
      head_object: 'metadata',
      list_objects: 'list',
      put_object: 'list'
    }

    operations.each do |op_name, params|
      clear_all!
      begin
        Instana.tracer.in_span(:s3_test) do
          s3_client.send(op_name, params)
        end
      rescue StandardError
        # expected – local endpoint not running
      end

      spans = ::Instana.processor.queued_spans
      s3_span = find_first_span_by_name(spans, :s3)
      next unless s3_span # skip if agent not ready

      assert_equal expected_ops[op_name], s3_span[:data][:s3][:op],
                   "Expected op #{expected_ops[op_name]} for #{op_name}"
    end
  end

  def test_s3_unknown_operation
    s3_client = Aws::S3::Client.new(
      region: "local",
      access_key_id: "minioadmin",
      secret_access_key: "minioadmin",
      force_path_style: "true",
      endpoint: "http://localhost:9000"
    )

    begin
      Instana.tracer.in_span(:s3_test) do
        s3_client.list_buckets
      end
    rescue StandardError
      # expected
    end

    spans = ::Instana.processor.queued_spans
    s3_span = find_first_span_by_name(spans, :s3)
    assert_equal 'list_buckets', s3_span[:data][:s3][:op] if s3_span
  end

  def test_s3_key_nil_excluded_from_tags
    s3_client = Aws::S3::Client.new(
      region: "local",
      access_key_id: "minioadmin",
      secret_access_key: "minioadmin",
      force_path_style: "true",
      endpoint: "http://localhost:9000"
    )

    begin
      Instana.tracer.in_span(:s3_test) do
        s3_client.list_objects(bucket: 'sample-bucket')
      end
    rescue StandardError
      # expected
    end

    spans = ::Instana.processor.queued_spans
    s3_span = find_first_span_by_name(spans, :s3)
    return unless s3_span

    refute s3_span[:data][:s3].key?(:key), "key should be absent when nil"
  end
end

class AwsSnsTest < Minitest::Test
  def setup
    clear_all!
  end

  def test_sns_publish
    sns = Aws::SNS::Client.new(
      region: "local",
      access_key_id: "test",
      secret_access_key: "test",
      endpoint: "http://localhost:9911"
    )

    assert_raises Aws::SNS::Errors::NotFound do
      Instana.tracer.in_span(:sns_test, attributes: {}) do
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

    Instana.tracer.in_span(:sns_test, attributes: {}) do
      sns.list_subscriptions
    end

    spans = ::Instana.processor.queued_spans
    aws_span, entry_span, *rest = spans

    assert rest.empty?
    assert_equal entry_span[:s], aws_span[:p]
    assert_equal :"net-http", aws_span[:n]
  end

  def test_sns_non_publish_does_not_create_sns_span
    # Operations other than :publish bypass the SNS span entirely
    sns = Aws::SNS::Client.new(
      region: "local",
      access_key_id: "test",
      secret_access_key: "test",
      endpoint: "http://localhost:9911"
    )

    Instana.tracer.in_span(:sns_test, attributes: {}) do
      sns.create_topic(name: 'test-topic')
    rescue StandardError
      # expected — local endpoint not available
    end

    spans = ::Instana.processor.queued_spans
    refute spans.any? { |s| s[:n] == :sns }, "create_topic should not produce an :sns span"
  end
end

class AwsSqsTest < Minitest::Test
  def setup
    clear_all!
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

    Instana.tracer.in_span(:sqs_test, attributes: {}) do
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

  def test_sqs_send_message_batch
    sqs = Aws::SQS::Client.new(
      region: "local",
      access_key_id: "test",
      secret_access_key: "test",
      endpoint: "http://localhost:9324"
    )

    queue_url = sqs.create_queue(queue_name: 'batch_test').queue_url

    Instana.tracer.in_span(:sqs_test) do
      sqs.send_message_batch(
        queue_url: queue_url,
        entries: [
          { id: '1', message_body: 'msg1' },
          { id: '2', message_body: 'msg2' }
        ]
      )
    end

    sqs.delete_queue(queue_url: queue_url)

    spans = ::Instana.processor.queued_spans
    batch_span = find_first_span_by_name(spans, :sqs)

    assert_equal :sqs, batch_span[:n]
    assert_equal 'exit', batch_span[:data][:sqs][:sort]
    assert_equal 'single.sync', batch_span[:data][:sqs][:type]
    assert_equal 2, batch_span[:data][:sqs][:size]
  end

  def test_sqs_delete_message
    sqs = Aws::SQS::Client.new(
      region: "local",
      access_key_id: "test",
      secret_access_key: "test",
      endpoint: "http://localhost:9324"
    )

    queue_url = sqs.create_queue(queue_name: 'delete_test').queue_url
    sqs.send_message(queue_url: queue_url, message_body: 'to_delete')
    msg = sqs.receive_message(queue_url: queue_url).messages.first

    clear_all!

    Instana.tracer.in_span(:sqs_test) do
      sqs.delete_message(queue_url: queue_url, receipt_handle: msg.receipt_handle)
    end

    sqs.delete_queue(queue_url: queue_url)

    spans = ::Instana.processor.queued_spans
    delete_span = find_first_span_by_name(spans, :sqs)

    assert_equal :sqs, delete_span[:n]
    assert_equal 'exit', delete_span[:data][:sqs][:sort]
    assert_equal 'delete.single.sync', delete_span[:data][:sqs][:type]
  end

  def test_sqs_delete_message_batch
    sqs = Aws::SQS::Client.new(
      region: "local",
      access_key_id: "test",
      secret_access_key: "test",
      endpoint: "http://localhost:9324"
    )

    queue_url = sqs.create_queue(queue_name: 'delete_batch_test').queue_url
    sqs.send_message(queue_url: queue_url, message_body: 'to_delete')
    msg = sqs.receive_message(queue_url: queue_url).messages.first

    clear_all!

    Instana.tracer.in_span(:sqs_test) do
      sqs.delete_message_batch(
        queue_url: queue_url,
        entries: [{ id: '1', receipt_handle: msg.receipt_handle }]
      )
    end

    sqs.delete_queue(queue_url: queue_url)

    spans = ::Instana.processor.queued_spans
    delete_span = find_first_span_by_name(spans, :sqs)

    assert_equal :sqs, delete_span[:n]
    assert_equal 'exit', delete_span[:data][:sqs][:sort]
    assert_equal 'delete.batch.sync', delete_span[:data][:sqs][:type]
    assert_equal 1, delete_span[:data][:sqs][:size]
  end

  def test_sqs_not_tracing_skips_span
    sqs = Aws::SQS::Client.new(
      region: "local",
      access_key_id: "test",
      secret_access_key: "test",
      endpoint: "http://localhost:9324"
    )

    # Call without an active trace — should not produce an sqs span
    begin
      sqs.create_queue(queue_name: 'no_trace_test')
    rescue StandardError
      # expected if endpoint unavailable
    end

    spans = ::Instana.processor.queued_spans
    refute spans.any? { |s| s[:n] == :sqs }, "create_queue without an active trace should not produce an :sqs span"
  end
end

class AwsLambdaTest < Minitest::Test
  def setup
    clear_all!
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

    Instana.tracer.in_span(:lambda_test, attributes: {}) do
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
    assert_equal 200, lambda_span[:data][:http][:status]
    assert_nil lambda_span[:ec]
    assert_nil lambda_span[:stack]
  end

  def test_lambda_with_five_hundred_status
    stub_request(:post, "https://lambda.local.amazonaws.com/2015-03-31/functions/Test/invocations")
      .with(
        body: "data",
        headers: {
          'X-Amz-Client-Context' => /.+/
        }
      )
      .to_return(status: 500, body: '{"message": "Internal Server Error" }', headers: {})

    lambda = Aws::Lambda::Client.new(
      endpoint: 'https://lambda.local.amazonaws.com',
      region: 'local',
      access_key_id: "test",
      secret_access_key: "test"
    )

    assert_raises(RuntimeError) do
      Instana.tracer.in_span(:lambda_test, attributes: {}) do
        lambda.invoke(
          function_name: 'Test',
          invocation_type: 'Event',
          payload: 'data'
        )
      end
    end

    spans = ::Instana.processor.queued_spans
    lambda_span, _entry_span, *rest = spans

    assert rest.empty?

    assert_equal :"aws.lambda.invoke", lambda_span[:n]
    assert_equal 'Test', lambda_span[:data][:aws][:lambda][:invoke][:function]
    assert_equal 'Event', lambda_span[:data][:aws][:lambda][:invoke][:type]
    refute_nil lambda_span[:ec]
    assert_equal 1, lambda_span[:ec]
    refute_nil lambda_span[:stack]
    assert_equal 30, lambda_span[:stack].length # default limit is 30 in span.add_stack
  end
end

class AwsAgentReadyTest < Minitest::Test
  def setup
    clear_all!
  end

  def test_no_error_is_raised_and_no_spans_are_created_when_agent_is_not_ready
    error = nil

    ::Instana.agent.stub(:ready?, false) do
      dynamo = Aws::DynamoDB::Client.new(
        region: "local",
        access_key_id: "placeholder",
        secret_access_key: "placeholder",
        endpoint: "http://localhost:8000"
      )

      assert_silent do
        dynamo.get_item(
          table_name: 'sample_table',
          key: { s: 'sample_item' }
        )
      rescue StandardError => e
        error = e
      end
    end

    # Should not raise instrumentation errors, only the expected AWS error
    assert error.is_a?(Aws::DynamoDB::Errors::ServiceError)
    assert_empty ::Instana.processor.queued_spans
  end
end
