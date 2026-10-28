# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2021

require 'test_helper'

class AwsDynamoDbTest < Minitest::Test
  def setup
    clear_all!
    @dynamo_client = Aws::DynamoDB::Client.new(
      region: "local",
      access_key_id: "placeholder",
      secret_access_key: "placeholder",
      endpoint: "http://localhost:8000"
    )
  end

  def test_dynamo_db
    assert_raises Aws::DynamoDB::Errors::ResourceNotFoundException do
      Instana.tracer.in_span(:dynamo_test, attributes: {}) do
        @dynamo_client.get_item(
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
          @dynamo_client.send(op_name, params)
        end
      rescue StandardError
        # expected – local endpoint not running
      end

      spans = ::Instana.processor.queued_spans
      dynamo_span = find_first_span_by_name(spans, :dynamodb)
      refute_nil dynamo_span, "Expected a :dynamodb span for #{op_name}"

      assert_equal expected_op, dynamo_span[:data][:dynamodb][:op],
                   "Expected op #{expected_op} for #{op_name}"
    end
  end

  def test_dynamo_db_unknown_operation
    begin
      Instana.tracer.in_span(:dynamo_test) do
        @dynamo_client.describe_table(table_name: 'some_table')
      end
    rescue StandardError
      # expected
    end

    spans = ::Instana.processor.queued_spans
    dynamo_span = find_first_span_by_name(spans, :dynamodb)
    refute_nil dynamo_span, "Expected a :dynamodb span to be generated"

    assert_equal 'describe_table', dynamo_span[:data][:dynamodb][:op]
  end

  def test_dynamo_db_global_table_name_fallback
    begin
      Instana.tracer.in_span(:dynamo_test) do
        @dynamo_client.describe_global_table(global_table_name: 'my_global_table')
      end
    rescue StandardError
      # expected
    end

    spans = ::Instana.processor.queued_spans
    dynamo_span = find_first_span_by_name(spans, :dynamodb)
    refute_nil dynamo_span, "Expected a :dynamodb span to be generated"

    assert_equal 'my_global_table', dynamo_span[:data][:dynamodb][:table]
  end
end

class AwsS3Test < Minitest::Test
  def setup
    clear_all!
    @s3_client = Aws::S3::Client.new(
      region: "local",
      access_key_id: "minioadmin",
      secret_access_key: "minioadmin",
      force_path_style: "true",
      endpoint: "http://localhost:9000"
    )
  end

  def test_s3
    assert_raises Aws::S3::Errors::NoSuchBucket do
      Instana.tracer.in_span(:s3_test, attributes: {}) do
        @s3_client.get_object(
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
          @s3_client.send(op_name, params)
        end
      rescue StandardError
        # expected – local endpoint not running
      end

      spans = ::Instana.processor.queued_spans
      s3_span = find_first_span_by_name(spans, :s3)
      refute_nil s3_span, "Expected an :s3 span for #{op_name}"

      assert_equal expected_ops[op_name], s3_span[:data][:s3][:op],
                   "Expected op #{expected_ops[op_name]} for #{op_name}"
    end
  end

  def test_s3_unknown_operation
    begin
      Instana.tracer.in_span(:s3_test) do
        @s3_client.list_buckets
      end
    rescue StandardError
      # expected
    end

    spans = ::Instana.processor.queued_spans
    s3_span = find_first_span_by_name(spans, :s3)
    refute_nil s3_span, "Expected an :s3 span to be generated"

    assert_equal 'list_buckets', s3_span[:data][:s3][:op]
  end

  def test_s3_key_nil_excluded_from_tags
    begin
      Instana.tracer.in_span(:s3_test) do
        @s3_client.list_objects(bucket: 'sample-bucket')
      end
    rescue StandardError
      # expected
    end

    spans = ::Instana.processor.queued_spans
    s3_span = find_first_span_by_name(spans, :s3)
    refute_nil s3_span, "Expected an :s3 span to be generated"

    s3_data = s3_span.dig(:data, :s3)
    refute_nil s3_data, "Expected span to contain :data -> :s3 payload"
    refute s3_data.key?(:key), "key should be absent from s3 tags when nil"
  end
end

class AwsSnsTest < Minitest::Test
  def setup
    clear_all!
    @sns_client = Aws::SNS::Client.new(
      region: "local",
      access_key_id: "test",
      secret_access_key: "test",
      endpoint: "http://localhost:9911"
    )
  end

  def test_sns_publish
    assert_raises Aws::SNS::Errors::NotFound do
      Instana.tracer.in_span(:sns_test, attributes: {}) do
        @sns_client.publish(
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
    Instana.tracer.in_span(:sns_test, attributes: {}) do
      @sns_client.list_subscriptions
    end

    spans = ::Instana.processor.queued_spans
    aws_span, entry_span, *rest = spans

    assert rest.empty?
    assert_equal entry_span[:s], aws_span[:p]
    assert_equal :"net-http", aws_span[:n]
  end

  def test_sns_non_publish_does_not_create_sns_span
    # Operations other than :publish bypass the SNS span entirely
    Instana.tracer.in_span(:sns_test, attributes: {}) do
      @sns_client.create_topic(name: 'test-topic')
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
    @sqs_client = Aws::SQS::Client.new(
      region: "local",
      access_key_id: "test",
      secret_access_key: "test",
      endpoint: "http://localhost:9324"
    )
  end

  def test_sqs
    create_response = nil
    get_url_response = nil

    Instana.tracer.in_span(:sqs_test, attributes: {}) do
      create_response = @sqs_client.create_queue(queue_name: 'test')
      get_url_response = @sqs_client.get_queue_url(queue_name: 'test')
      @sqs_client.send_message(queue_url: create_response.queue_url, message_body: 'Sample')
    end

    received = @sqs_client.receive_message(
      queue_url: create_response.queue_url,
      message_attribute_names: ['All']
    )
    @sqs_client.delete_queue(queue_url: create_response.queue_url)
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
    queue_url = @sqs_client.create_queue(queue_name: 'batch_test').queue_url

    Instana.tracer.in_span(:sqs_test) do
      @sqs_client.send_message_batch(
        queue_url: queue_url,
        entries: [
          { id: '1', message_body: 'msg1' },
          { id: '2', message_body: 'msg2' }
        ]
      )
    end

    @sqs_client.delete_queue(queue_url: queue_url)

    spans = ::Instana.processor.queued_spans
    batch_span = find_first_span_by_name(spans, :sqs)

    assert_equal :sqs, batch_span[:n]
    assert_equal 'exit', batch_span[:data][:sqs][:sort]
    assert_equal 'single.sync', batch_span[:data][:sqs][:type]
    assert_equal 2, batch_span[:data][:sqs][:size]
  end

  def test_sqs_delete_message
    queue_url = @sqs_client.create_queue(queue_name: 'delete_test').queue_url
    @sqs_client.send_message(queue_url: queue_url, message_body: 'to_delete')
    msg = @sqs_client.receive_message(queue_url: queue_url).messages.first

    clear_all!

    Instana.tracer.in_span(:sqs_test) do
      @sqs_client.delete_message(queue_url: queue_url, receipt_handle: msg.receipt_handle)
    end

    @sqs_client.delete_queue(queue_url: queue_url)

    spans = ::Instana.processor.queued_spans
    delete_span = find_first_span_by_name(spans, :sqs)

    assert_equal :sqs, delete_span[:n]
    assert_equal 'exit', delete_span[:data][:sqs][:sort]
    assert_equal 'delete.single.sync', delete_span[:data][:sqs][:type]
  end

  def test_sqs_delete_message_batch
    queue_url = @sqs_client.create_queue(queue_name: 'delete_batch_test').queue_url
    @sqs_client.send_message(queue_url: queue_url, message_body: 'to_delete')
    msg = @sqs_client.receive_message(queue_url: queue_url).messages.first

    clear_all!

    Instana.tracer.in_span(:sqs_test) do
      @sqs_client.delete_message_batch(
        queue_url: queue_url,
        entries: [{ id: '1', receipt_handle: msg.receipt_handle }]
      )
    end

    @sqs_client.delete_queue(queue_url: queue_url)

    spans = ::Instana.processor.queued_spans
    delete_span = find_first_span_by_name(spans, :sqs)

    assert_equal :sqs, delete_span[:n]
    assert_equal 'exit', delete_span[:data][:sqs][:sort]
    assert_equal 'delete.batch.sync', delete_span[:data][:sqs][:type]
    assert_equal 1, delete_span[:data][:sqs][:size]
  end

  def test_sqs_not_tracing_skips_span
    # Call without an active trace — should not produce an sqs span
    begin
      @sqs_client.create_queue(queue_name: 'no_trace_test')
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
    @lambda_client = Aws::Lambda::Client.new(
      endpoint: 'https://lambda.local.amazonaws.com',
      region: 'local',
      access_key_id: "test",
      secret_access_key: "test"
    )
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

    Instana.tracer.in_span(:lambda_test, attributes: {}) do
      @lambda_client.invoke(
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

    assert_raises(RuntimeError) do
      Instana.tracer.in_span(:lambda_test, attributes: {}) do
        @lambda_client.invoke(
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

  def test_sns_publish_injects_trace_attributes
    # The WebMock error body proves the attributes are present; stub the endpoint to avoid the network.
    stub_request(:post, "http://localhost:9911/")
      .with(body: /X_INSTANA_T/)
      .to_return(status: 200, body: "<PublishResponse><PublishResult><MessageId>abc</MessageId></PublishResult></PublishResponse>", headers: { 'Content-Type' => 'text/xml' })

    injected = nil
    sns = Aws::SNS::Client.new(
      region: "local",
      access_key_id: "test",
      secret_access_key: "test",
      endpoint: "http://localhost:9911"
    )
    # Intercept params at the initialize step (before network), after the SNS plugin has run
    sns.handlers.add(
      Class.new(Seahorse::Client::Handler) do
        define_method(:call) do |ctx|
          injected = ctx.params[:message_attributes]&.dup
          super(ctx)
        end
      end,
      step: :initialize, priority: 0
    )

    Instana.tracer.in_span(:sns_attrs_test, attributes: {}) do
      sns.publish(topic_arn: 'topic:arn', message: 'Hello')
    end

    refute_nil injected, 'Expected message_attributes to be set'
    assert injected.key?('X_INSTANA_T'), 'Expected X_INSTANA_T in message_attributes'
    assert injected.key?('X_INSTANA_S'), 'Expected X_INSTANA_S in message_attributes'
    assert injected.key?('X_INSTANA_L'), 'Expected X_INSTANA_L in message_attributes'
    assert injected.key?('traceparent'), 'Expected traceparent in message_attributes'
    assert_equal 'String', injected['X_INSTANA_T'][:data_type]
    assert_equal 'String', injected['X_INSTANA_L'][:data_type]
    assert_equal 'String', injected['traceparent'][:data_type]
    assert_match(/00-[0-9a-f]{32}-[0-9a-f]{16}-[0-9a-f]{2}/, injected['traceparent'][:string_value])
  end

  def test_sqs_send_message_injects_trace_attributes
    stub_request(:post, %r{http://localhost:9324/.*})
      .to_return(
        status: 200,
        body: "{}",
        headers: { 'Content-Type' => 'application/x-amz-json-1.0' }
      )

    injected = nil
    sqs = Aws::SQS::Client.new(
      region: "local",
      access_key_id: "test",
      secret_access_key: "test",
      endpoint: "http://localhost:9324"
    )
    sqs.handlers.remove(Aws::SQS::Plugins::Md5s::Handler) if defined?(Aws::SQS::Plugins::Md5s::Handler)
    sqs.handlers.add(
      Class.new(Seahorse::Client::Handler) do
        define_method(:call) do |ctx|
          injected = ctx.params[:message_attributes]&.dup
          super(ctx)
        end
      end,
      step: :initialize, priority: 0
    )

    Instana.tracer.in_span(:sqs_attrs_test, attributes: {}) do
      sqs.send_message(queue_url: 'http://localhost:9324/queue/test', message_body: 'Hello SQS')
    end

    refute_nil injected, 'Expected message_attributes to be set'
    assert injected.key?('X_INSTANA_T'), 'Expected X_INSTANA_T in message_attributes'
    assert injected.key?('X_INSTANA_S'), 'Expected X_INSTANA_S in message_attributes'
    assert injected.key?('X_INSTANA_L'), 'Expected X_INSTANA_L in message_attributes'
    assert injected.key?('traceparent'), 'Expected traceparent in message_attributes'
    assert_equal 'String', injected['X_INSTANA_T'][:data_type]
    assert_equal 'String', injected['traceparent'][:data_type]
    assert_match(/00-[0-9a-f]{32}-[0-9a-f]{16}-[0-9a-f]{2}/, injected['traceparent'][:string_value])
  end

  def test_sqs_send_message_batch_injects_trace_attributes
    stub_request(:post, %r{http://localhost:9324/.*})
      .to_return(status: 200, body: "{}", headers: { 'Content-Type' => 'application/x-amz-json-1.0' })

    injected_entries = []
    sqs = Aws::SQS::Client.new(
      region: "local",
      access_key_id: "test",
      secret_access_key: "test",
      endpoint: "http://localhost:9324"
    )
    sqs.handlers.remove(Aws::SQS::Plugins::Md5s::Handler) if defined?(Aws::SQS::Plugins::Md5s::Handler)
    sqs.handlers.add(
      Class.new(Seahorse::Client::Handler) do
        define_method(:call) do |ctx|
          injected_entries = ctx.params[:entries]&.map { |e| e[:message_attributes]&.dup }
          super(ctx)
        end
      end,
      step: :initialize, priority: 0
    )

    Instana.tracer.in_span(:sqs_batch_attrs_test, attributes: {}) do
      sqs.send_message_batch(
        queue_url: 'http://localhost:9324/queue/test',
        entries: [{ id: '1', message_body: 'Hello batch' }]
      )
    end

    refute_empty injected_entries
    entry_attrs = injected_entries.first
    refute_nil entry_attrs
    assert entry_attrs.key?('X_INSTANA_T')
    assert entry_attrs.key?('traceparent')
    assert_equal 'String', entry_attrs['traceparent'][:data_type]
  end

  def test_sns_non_publish_not_modified
    # Phase 8.5 — non-:publish (list_subscriptions) → message_attributes not touched
    stub_request(:post, "http://localhost:9911/")
      .with(body: /ListSubscriptions/)
      .to_return(
        status: 200,
        body: "<ListSubscriptionsResponse><ListSubscriptionsResult><Subscriptions/></ListSubscriptionsResult></ListSubscriptionsResponse>",
        headers: { 'Content-Type' => 'text/xml' }
      )

    captured_params = nil
    sns = Aws::SNS::Client.new(
      region: "local",
      access_key_id: "test",
      secret_access_key: "test",
      endpoint: "http://localhost:9911"
    )
    sns.handlers.add(
      Class.new(Seahorse::Client::Handler) do
        define_method(:call) do |ctx|
          captured_params = ctx.params.dup
          super(ctx)
        end
      end,
      step: :initialize, priority: 0
    )

    Instana.tracer.in_span(:sns_other_test, attributes: {}) do
      sns.list_subscriptions
    end

    assert_nil captured_params&.dig(:message_attributes),
               'message_attributes should not be set for non-publish operations'
  end

  def test_lambda_invoke_injects_client_context
    # Phase 9.3 — :invoke with no existing ClientContext → decoded payload contains X-INSTANA-T/S/L
    stub_request(:post, "https://lambda.local.amazonaws.com/2015-03-31/functions/CtxTest/invocations")
      .with(headers: { 'X-Amz-Client-Context' => /.+/ })
      .to_return(status: 200, body: "", headers: {})

    lambda_client = Aws::Lambda::Client.new(
      endpoint: 'https://lambda.local.amazonaws.com',
      region: 'local',
      access_key_id: "test",
      secret_access_key: "test"
    )

    Instana.tracer.in_span(:lambda_ctx_test, attributes: {}) do
      lambda_client.invoke(function_name: 'CtxTest', payload: 'data')
    end

    request = WebMock::RequestRegistry.instance.requested_signatures.hash.keys.last
    encoded = request.headers['X-Amz-Client-Context']
    decoded = JSON.parse(Base64.strict_decode64(encoded))

    assert decoded.key?('X-INSTANA-T'), 'Expected X-INSTANA-T in ClientContext'
    assert decoded.key?('X-INSTANA-S'), 'Expected X-INSTANA-S in ClientContext'
    assert decoded.key?('X-INSTANA-L'), 'Expected X-INSTANA-L in ClientContext'
    assert decoded.key?('traceparent'), 'Expected traceparent in ClientContext'
    assert_match(/00-[0-9a-f]{32}-[0-9a-f]{16}-[0-9a-f]{2}/, decoded['traceparent'])
  end

  def test_lambda_invoke_merges_existing_client_context
    # Phase 9.4 — :invoke with existing ClientContext → Instana keys merged, original keys preserved
    original_ctx = Base64.strict_encode64(JSON.dump({ 'custom_key' => 'custom_value' }))

    stub_request(:post, "https://lambda.local.amazonaws.com/2015-03-31/functions/MergeTest/invocations")
      .with(headers: { 'X-Amz-Client-Context' => /.+/ })
      .to_return(status: 200, body: "", headers: {})

    lambda_client = Aws::Lambda::Client.new(
      endpoint: 'https://lambda.local.amazonaws.com',
      region: 'local',
      access_key_id: "test",
      secret_access_key: "test"
    )

    Instana.tracer.in_span(:lambda_merge_test, attributes: {}) do
      lambda_client.invoke(
        function_name: 'MergeTest',
        client_context: original_ctx,
        payload: 'data'
      )
    end

    request = WebMock::RequestRegistry.instance.requested_signatures.hash.keys.last
    encoded = request.headers['X-Amz-Client-Context']
    decoded = JSON.parse(Base64.strict_decode64(encoded))

    assert_equal 'custom_value', decoded['custom_key'], 'Original key must be preserved'
    assert decoded.key?('X-INSTANA-T'), 'Expected X-INSTANA-T merged in'
    assert decoded.key?('X-INSTANA-S'), 'Expected X-INSTANA-S merged in'
    assert decoded.key?('X-INSTANA-L'), 'Expected X-INSTANA-L merged in'
    assert decoded.key?('traceparent'), 'Expected traceparent merged in'
  end

  def test_no_error_is_raised_and_no_spans_are_created_when_agent_is_not_ready
    stub_request(:post, "http://localhost:8000/")
      .to_return(
        status: 400,
        body: '{"__type":"com.amazonaws.dynamodb.v20120810#ResourceNotFoundException","message":"Cannot find table"}',
        headers: { 'Content-Type' => 'application/x-amz-json-1.0' }
      )

    error = nil

    ::Instana.agent.stub(:ready?, false) do
      dynamo_client = Aws::DynamoDB::Client.new(
        region: "local",
        access_key_id: "placeholder",
        secret_access_key: "placeholder",
        endpoint: "http://localhost:8000"
      )

      assert_silent do
        dynamo_client.get_item(
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

class AwsContextPropagationTest < Minitest::Test
  SNS_PUBLISH_RESPONSE = '<PublishResponse><PublishResult>' \
                         '<MessageId>abc</MessageId>' \
                         '</PublishResult></PublishResponse>'.freeze

  SNS_PUBLISH_BATCH_TWO_RESPONSE = '<PublishBatchResponse><PublishBatchResult>' \
                                   '<Successful>' \
                                   '<member><Id>1</Id><MessageId>m1</MessageId></member>' \
                                   '<member><Id>2</Id><MessageId>m2</MessageId></member>' \
                                   '</Successful><Failed/>' \
                                   '</PublishBatchResult></PublishBatchResponse>'.freeze

  SNS_PUBLISH_BATCH_ONE_RESPONSE = '<PublishBatchResponse><PublishBatchResult>' \
                                   '<Successful>' \
                                   '<member><Id>1</Id><MessageId>m1</MessageId></member>' \
                                   '</Successful><Failed/>' \
                                   '</PublishBatchResult></PublishBatchResponse>'.freeze

  SNS_XML_HEADERS = { 'Content-Type' => 'text/xml' }.freeze
  SQS_JSON_HEADERS = { 'Content-Type' => 'application/x-amz-json-1.0' }.freeze

  def setup
    clear_all!
  end

  # ---------------------------------------------------------------------------
  # SNS helpers
  # ---------------------------------------------------------------------------

  def build_sns_client
    Aws::SNS::Client.new(
      region: "local",
      access_key_id: "test",
      secret_access_key: "test",
      endpoint: "http://localhost:9911"
    )
  end

  def add_sns_message_attribute_interceptor(client, &block)
    client.handlers.add(
      Class.new(Seahorse::Client::Handler) do
        define_method(:call) do |ctx|
          block.call(ctx)
          super(ctx)
        end
      end,
      step: :initialize, priority: 0
    )
  end

  # ---------------------------------------------------------------------------
  # SQS helpers
  # ---------------------------------------------------------------------------

  def build_sqs_client
    sqs = Aws::SQS::Client.new(
      region: "local",
      access_key_id: "test",
      secret_access_key: "test",
      endpoint: "http://localhost:9324"
    )
    sqs.handlers.remove(Aws::SQS::Plugins::Md5s::Handler) if defined?(Aws::SQS::Plugins::Md5s::Handler)
    sqs
  end

  def add_sqs_message_attribute_interceptor(client, &block)
    client.handlers.add(
      Class.new(Seahorse::Client::Handler) do
        define_method(:call) do |ctx|
          block.call(ctx)
          super(ctx)
        end
      end,
      step: :initialize, priority: 0
    )
  end

  def full_attrs
    (1..6).each_with_object({}) do |i, h|
      h["app_attr_#{i}"] = { data_type: 'String', string_value: "val#{i}" }
    end
  end

  # ---------------------------------------------------------------------------
  # SNS publish — all 5 headers injected when slots are available
  # ---------------------------------------------------------------------------

  def test_sns_publish_injects_only_w3c_headers_when_attributes_almost_full
    stub_request(:post, "http://localhost:9911/")
      .to_return(status: 200, body: SNS_PUBLISH_RESPONSE, headers: SNS_XML_HEADERS)

    injected = nil
    sns = build_sns_client
    add_sns_message_attribute_interceptor(sns) { |ctx| injected = ctx.params[:message_attributes]&.dup }

    Instana.tracer.in_span(:sns_fallback_test, attributes: {}) do
      sns.publish(topic_arn: 'topic:arn', message: 'Hello', message_attributes: full_attrs)
    end

    refute_nil injected
    assert injected.key?('traceparent'), 'Expected traceparent when slots < 5'
    assert injected.key?('tracestate'),  'Expected tracestate when slots < 5'
    refute injected.key?('X_INSTANA_T'), 'Expected X_INSTANA_T to be omitted when slots < 5'
    refute injected.key?('X_INSTANA_S'), 'Expected X_INSTANA_S to be omitted when slots < 5'
    refute injected.key?('X_INSTANA_L'), 'Expected X_INSTANA_L to be omitted when slots < 5'
    assert injected.size <= 10, 'Total message attributes must not exceed SNS limit of 10'
  end

  # ---------------------------------------------------------------------------
  # SNS publish_batch — all 5 headers injected into every entry (empty attrs)
  # ---------------------------------------------------------------------------

  def test_sns_publish_batch_injects_trace_attributes_into_each_entry
    stub_request(:post, "http://localhost:9911/")
      .to_return(status: 200, body: SNS_PUBLISH_BATCH_TWO_RESPONSE, headers: SNS_XML_HEADERS)

    injected_entries = []
    sns = build_sns_client
    add_sns_message_attribute_interceptor(sns) do |ctx|
      injected_entries = ctx.params[:publish_batch_request_entries]&.map do |e|
        e[:message_attributes]&.dup
      end
    end

    Instana.tracer.in_span(:sns_batch_test, attributes: {}) do
      sns.publish_batch(
        topic_arn: 'topic:arn',
        publish_batch_request_entries: [
          { id: '1', message: 'First' },
          { id: '2', message: 'Second' }
        ]
      )
    end

    assert_equal 2, injected_entries.size, 'Expected attributes captured for both entries'
    injected_entries.each_with_index do |attrs, i|
      refute_nil attrs, "Expected message_attributes on entry #{i + 1}"
      assert attrs.key?('X_INSTANA_T'), "Expected X_INSTANA_T on entry #{i + 1}"
      assert attrs.key?('X_INSTANA_S'), "Expected X_INSTANA_S on entry #{i + 1}"
      assert attrs.key?('X_INSTANA_L'), "Expected X_INSTANA_L on entry #{i + 1}"
      assert attrs.key?('traceparent'), "Expected traceparent on entry #{i + 1}"
      assert_match(
        /00-[0-9a-f]{32}-[0-9a-f]{16}-[0-9a-f]{2}/,
        attrs['traceparent'][:string_value]
      )
    end
  end

  # ---------------------------------------------------------------------------
  # SNS publish_batch — falls back to W3C-only when entry slots < 5
  # ---------------------------------------------------------------------------

  def test_sns_publish_batch_injects_only_w3c_headers_when_entry_attributes_almost_full
    stub_request(:post, "http://localhost:9911/")
      .to_return(status: 200, body: SNS_PUBLISH_BATCH_ONE_RESPONSE, headers: SNS_XML_HEADERS)

    injected_entries = []
    sns = build_sns_client
    add_sns_message_attribute_interceptor(sns) do |ctx|
      injected_entries = ctx.params[:publish_batch_request_entries]&.map do |e|
        e[:message_attributes]&.dup
      end
    end

    Instana.tracer.in_span(:sns_batch_fallback_test, attributes: {}) do
      sns.publish_batch(
        topic_arn: 'topic:arn',
        publish_batch_request_entries: [
          { id: '1', message: 'Hello', message_attributes: full_attrs }
        ]
      )
    end

    attrs = injected_entries.first
    refute_nil attrs
    assert attrs.key?('traceparent'), 'Expected traceparent when slots < 5'
    assert attrs.key?('tracestate'),  'Expected tracestate when slots < 5'
    refute attrs.key?('X_INSTANA_T'), 'Expected X_INSTANA_T to be omitted when slots < 5'
    refute attrs.key?('X_INSTANA_S'), 'Expected X_INSTANA_S to be omitted when slots < 5'
    refute attrs.key?('X_INSTANA_L'), 'Expected X_INSTANA_L to be omitted when slots < 5'
    assert attrs.size <= 10, 'Total message attributes per batch entry must not exceed SNS limit of 10'
  end

  # ---------------------------------------------------------------------------
  # SQS send_message — falls back to W3C-only when slots < 5
  # ---------------------------------------------------------------------------

  def test_sqs_send_message_injects_only_w3c_headers_when_attributes_almost_full
    stub_request(:post, %r{http://localhost:9324/.*})
      .to_return(status: 200, body: '{}', headers: SQS_JSON_HEADERS)

    injected = nil
    sqs = build_sqs_client
    add_sqs_message_attribute_interceptor(sqs) { |ctx| injected = ctx.params[:message_attributes]&.dup }

    Instana.tracer.in_span(:sqs_fallback_test, attributes: {}) do
      sqs.send_message(
        queue_url: 'http://localhost:9324/queue/test',
        message_body: 'Hello SQS',
        message_attributes: full_attrs
      )
    end

    refute_nil injected
    assert injected.key?('traceparent'), 'Expected traceparent when slots < 5'
    assert injected.key?('tracestate'),  'Expected tracestate when slots < 5'
    refute injected.key?('X_INSTANA_T'), 'Expected X_INSTANA_T to be omitted when slots < 5'
    refute injected.key?('X_INSTANA_S'), 'Expected X_INSTANA_S to be omitted when slots < 5'
    refute injected.key?('X_INSTANA_L'), 'Expected X_INSTANA_L to be omitted when slots < 5'
    assert injected.size <= 10, 'Total message attributes must not exceed SQS limit of 10'
  end
end
