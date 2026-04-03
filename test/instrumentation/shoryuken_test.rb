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

  def test_no_error_is_raised_and_no_spans_are_created_when_agent_is_not_ready
    clear_all!
    error = nil

    message = OpenStruct.new(
      queue_url: 'http://example.com'
    )

    ::Instana.agent.stub(:ready?, false) do
      assert_silent do
        @middleware.call(nil, nil, message, nil) {}
      rescue StandardError => e
        error = e
      end
    end

    assert_nil error
    assert_empty ::Instana.processor.queued_spans
  end
end
