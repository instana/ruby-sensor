# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2021

require 'test_helper'

class ServerlessTest < Minitest::Test
  def setup
    @mock_agent = Minitest::Mock.new
    @mock_agent.expect(:send_bundle, true, [])
    @subject = Instana::Serverless.new(agent: @mock_agent)
  end

  def teardown
    @mock_agent.verify
  end

  def test_lambda_send_error
    mock_logger = Minitest::Mock.new
    mock_logger.expect(:error, true, [String])

    @mock_agent.expect(:send_bundle, true) { |_args| raise StandardError, 'error' }

    mock_context = OpenStruct.new(
      invoked_function_arn: 'test_arn',
      function_name: 'test_function',
      function_version: '$TEST'
    )

    subject = Instana::Serverless.new(agent: @mock_agent, logger: mock_logger)
    subject.wrap_aws(nil, mock_context) { 0 }
    subject.wrap_aws(nil, mock_context) { 0 }

    mock_logger.verify
  end

  def test_lambda_data
    clear_all!

    mock_context = OpenStruct.new(
      invoked_function_arn: 'test_arn',
      function_name: 'test_function',
      function_version: '$TEST'
    )

    @subject.wrap_aws(nil, mock_context) { 0 }

    lambda_span, *rest = Instana.processor.queued_spans
    assert rest.empty?

    data = lambda_span[:data][:lambda]

    assert_equal 'aws:api.gateway.noproxy', lambda_span[:data][:lambda][:trigger]

    assert_equal mock_context.invoked_function_arn, data[:arn]
    assert_equal mock_context.function_name, data[:functionName]
    assert_equal mock_context.function_version, data[:functionVersion]
    assert_equal 'ruby', data[:runtime]
  end

  def test_lambda_http
    clear_all!

    mock_id = Instana::Util.generate_id
    mock_context = OpenStruct.new(
      invoked_function_arn: 'test_arn',
      function_name: 'test_function',
      function_version: '$TEST'
    )
    mock_http = {
      "headers" => {
        "Accept" => "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8",
        "Accept-Encoding" => "gzip, deflate",
        "Accept-Language" => "en-US,en;q=0.5",
        "Connection" => "keep-alive",
        "Host" => "127.0.0.1:3000",
        "Upgrade-Insecure-Requests" => "1",
        "User-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:87.0) Gecko/20100101 Firefox/87.0",
        "X-Forwarded-Port" => "3000",
        "X-Forwarded-Proto" => "http",
        'X-Instana-S' => mock_id,
        'X-Instana-T' => mock_id,
        'X-Instana-L' => '1'
      },
      "httpMethod" => "GET",
      "path" => "/hello",
      "queryStringParameters" => {"test" => "abcde"}
    }

    @subject.wrap_aws(mock_http, mock_context) { 0 }

    lambda_span, *rest = Instana.processor.queued_spans
    assert rest.empty?

    data = lambda_span[:data][:http]

    assert_equal 'aws:api.gateway', lambda_span[:data][:lambda][:trigger]
    assert_equal mock_id, lambda_span[:t]
    assert_equal mock_id, lambda_span[:p]

    assert_equal 'GET', data[:method]
    assert_equal '/hello', data[:url]
    assert_equal '127.0.0.1:3000', data[:host]
    assert_equal 'test=abcde', data[:params]
  end

  def test_lambda_alb
    clear_all!

    mock_id = Instana::Util.generate_id
    mock_context = OpenStruct.new(
      invoked_function_arn: 'test_arn',
      function_name: 'test_function',
      function_version: '$TEST'
    )
    mock_http = {
      "headers" => {
        "Accept" => "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8",
        "Accept-Encoding" => "gzip, deflate",
        "Accept-Language" => "en-US,en;q=0.5",
        "Connection" => "keep-alive",
        "Host" => "127.0.0.1:3000",
        "Upgrade-Insecure-Requests" => "1",
        "User-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:87.0) Gecko/20100101 Firefox/87.0",
        "X-Forwarded-Port" => "3000",
        "X-Forwarded-Proto" => "http",
        'X-Instana-S' => mock_id,
        'X-Instana-T' => mock_id,
        'X-Instana-L' => '1'
      },
      "httpMethod" => "GET",
      "path" => "/hello",
      "requestContext" => { "elb" => {} }
    }

    @subject.wrap_aws(mock_http, mock_context) { 0 }

    lambda_span, *rest = Instana.processor.queued_spans
    assert rest.empty?

    data = lambda_span[:data][:http]

    assert_equal 'aws:application.load.balancer', lambda_span[:data][:lambda][:trigger]
    assert_equal mock_id, lambda_span[:t]
    assert_equal mock_id, lambda_span[:p]

    assert_equal 'GET', data[:method]
    assert_equal '/hello', data[:url]
    assert_equal '127.0.0.1:3000', data[:host]
    assert_equal '', data[:params]
  end

  def test_lambda_cw_event
    clear_all!

    mock_context = OpenStruct.new(
      invoked_function_arn: 'test_arn',
      function_name: 'test_function',
      function_version: '$TEST'
    )
    mock_event = {
      "detail-type" => "Scheduled Event",
      "source" => "aws.events",
      "id" => "test",
      "resources" => ["test"]
    }

    @subject.wrap_aws(mock_event, mock_context) { 0 }

    lambda_span, *rest = Instana.processor.queued_spans
    assert rest.empty?

    data = lambda_span[:data][:lambda][:cw][:events]

    assert_equal 'aws:cloudwatch.events', lambda_span[:data][:lambda][:trigger]
    assert_equal 'test', data[:id]
    assert_equal ["test"], data[:resources]
  end

  def test_lambda_cw_logs
    clear_all!

    mock_context = OpenStruct.new(
      invoked_function_arn: 'test_arn',
      function_name: 'test_function',
      function_version: '$TEST'
    )
    mock_event = {
      "awslogs" => {"data" => File.read('test/support/serverless/cloudwatch_log.bin')}
    }

    @subject.wrap_aws(mock_event, mock_context) { 0 }

    lambda_span, *rest = Instana.processor.queued_spans
    assert rest.empty?

    data = lambda_span[:data][:lambda][:cw][:logs]

    assert_equal 'aws:cloudwatch.logs', lambda_span[:data][:lambda][:trigger]
    assert_equal '/aws/lambda/echo-nodejs', data[:group]
    assert_equal '2019/03/13/[$LATEST]94fa867e5374431291a7fc14e2f56ae7', data[:stream]
  end

  def test_lambda_cw_error
    clear_all!

    mock_context = OpenStruct.new(
      invoked_function_arn: 'test_arn',
      function_name: 'test_function',
      function_version: '$TEST'
    )
    mock_event = {
      "awslogs" => {"data" => "error"}
    }

    @subject.wrap_aws(mock_event, mock_context) { 0 }

    lambda_span, *rest = Instana.processor.queued_spans
    assert rest.empty?

    data = lambda_span[:data][:lambda][:cw][:logs]

    assert_equal 'aws:cloudwatch.logs', lambda_span[:data][:lambda][:trigger]
    assert_equal 'incorrect header check', data[:decodingError]
  end

  def test_lambda_s3
    clear_all!

    mock_context = OpenStruct.new(
      invoked_function_arn: 'test_arn',
      function_name: 'test_function',
      function_version: '$TEST'
    )
    mock_event = {
      "Records" => [
        {
          "source" => "aws:s3",
          "eventName" => "test",
          "s3" => {
            "bucket" => {"name" => "test_bucket"},
            "object" => {"key" => "test_key"}
          }
        }
      ]
    }

    @subject.wrap_aws(mock_event, mock_context) { 0 }

    lambda_span, *rest = Instana.processor.queued_spans
    assert rest.empty?

    data = lambda_span[:data][:lambda][:s3]

    assert_equal 'aws:s3', lambda_span[:data][:lambda][:trigger]
    assert_equal 1, data[:events].length

    assert_equal 'test', data[:events].first[:name]
    assert_equal 'test_bucket', data[:events].first[:bucket]
    assert_equal 'test_key', data[:events].first[:object]
  end

  def test_lambda_s3_no_object
    clear_all!

    mock_context = OpenStruct.new(
      invoked_function_arn: 'test_arn',
      function_name: 'test_function',
      function_version: '$TEST'
    )
    mock_event = {
      "Records" => [
        {
          "source" => "aws:s3",
          "eventName" => "test"
        }
      ]
    }

    @subject.wrap_aws(mock_event, mock_context) { 0 }

    lambda_span, *rest = Instana.processor.queued_spans
    assert rest.empty?

    data = lambda_span[:data][:lambda][:s3]

    assert_equal 'aws:s3', lambda_span[:data][:lambda][:trigger]
    assert_equal 1, data[:events].length

    assert_equal 'test', data[:events].first[:name]
    assert_nil data[:events].first[:bucket]
    assert_nil data[:events].first[:object]
  end

  def test_lambda_sqs
    clear_all!

    mock_context = OpenStruct.new(
      invoked_function_arn: 'test_arn',
      function_name: 'test_function',
      function_version: '$TEST'
    )
    mock_event = {
      "Records" => [
        {
          "source" => "aws:sqs",
          "eventSourceARN" => "test_arn"
        }
      ]
    }

    @subject.wrap_aws(mock_event, mock_context) { 0 }

    lambda_span, *rest = Instana.processor.queued_spans
    assert rest.empty?

    data = lambda_span[:data][:lambda][:sqs]

    assert_equal 'aws:sqs', lambda_span[:data][:lambda][:trigger]
    assert_equal 1, data[:messages].length

    assert_equal 'test_arn', data[:messages].first[:queue]
  end
end
