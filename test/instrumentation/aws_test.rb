# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2021

require 'test_helper'

class AwsTest < Minitest::Test
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

  def test_s3
    dynamo = Aws::S3::Client.new(
      region: "local",
      access_key_id: "minioadmin",
      secret_access_key: "minioadmin",
      endpoint: "http://localhost:9000"
    )

    assert_raises Aws::S3::Errors::NoSuchBucket do
      Instana::Tracer.start_or_continue_trace(:s3_test, {}) do
        dynamo.get_object(
          bucket: 'sample_bucket',
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
    assert_equal 'sample_bucket', s3_span[:data][:s3][:bucket]
    assert_equal 'sample_key', s3_span[:data][:s3][:key]
  end
end
