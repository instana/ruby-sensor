# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2021

require 'test_helper'

class AwsTest < Minitest::Test # rubocop:disable Metrics/ClassLength
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

  def test_lambda_with_500_status
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
    assert_equal 'String', injected['X_INSTANA_T'][:data_type]
    assert_equal 'String', injected['X_INSTANA_L'][:data_type]
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
