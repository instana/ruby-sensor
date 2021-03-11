# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2021

require 'test_helper'
require 'ostruct'

class ShoryukenTest < Minitest::Test
  def setup
    clear_all!
    @middleware = Instana::Instrumentation::Shoryuken.new
  end

  def test_start_trace_with_context
    id = Instana::Util.generate_id
    message = OpenStruct.new(
      queue_url: 'http://example.com',
      message_attributes: {
        "X_INSTANA_T" => OpenStruct.new(string_value: id),
        "X_INSTANA_S" => OpenStruct.new(string_value: id),
        "X_INSTANA_L" => OpenStruct.new(string_value: '1')
      }
    )

    @middleware.call(nil, nil, message, nil) {}

    span = ::Instana.processor.queued_spans.first

    assert_equal id, span[:t]
    assert_equal id, span[:p]
    assert_equal 'entry', span[:data][:sqs][:sort]
    assert_equal 'http://example.com', span[:data][:sqs][:queue]
  end

  def test_start_trace
    message = OpenStruct.new(
      queue_url: 'http://example.com'
    )

    @middleware.call(nil, nil, message, nil) {}

    span = ::Instana.processor.queued_spans.first

    assert_nil span[:p]
    assert_equal 'entry', span[:data][:sqs][:sort]
    assert_equal 'http://example.com', span[:data][:sqs][:queue]
  end
end
