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

  def test_array_message_yields_without_span
    # When sqs_message is an Array, call should just yield without creating a span
    result = @middleware.call(nil, nil, ['msg1', 'msg2'], nil) { :batch_result }

    assert_equal :batch_result, result
    assert_empty ::Instana.processor.queued_spans
  end

  def test_message_with_nil_attributes
    # message_attributes present but keys missing — read_message_header returns nil
    message = OpenStruct.new(
      queue_url: 'http://example.com',
      message_attributes: {}
    )

    @middleware.call(nil, nil, message, nil) {}

    span = ::Instana.processor.queued_spans.first
    assert_nil span[:p], "No parent context when headers are absent"
    assert_equal 'entry', span[:data][:sqs][:sort]
  end

  def test_message_with_non_string_value_attribute
    # attribute exists but does not respond to string_value — should be ignored
    message = OpenStruct.new(
      queue_url: 'http://example.com',
      message_attributes: {
        'X_INSTANA_T' => OpenStruct.new # no string_value method
      }
    )

    @middleware.call(nil, nil, message, nil) {}

    span = ::Instana.processor.queued_spans.first
    refute_nil span
    assert_nil span[:p]
  end

  def test_start_trace_with_w3c_traceparent
    message = OpenStruct.new(
      queue_url: 'http://example.com',
      message_attributes: {
        'traceparent' => OpenStruct.new(string_value: '00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01')
      }
    )

    @middleware.call(nil, nil, message, nil) {}

    span = ::Instana.processor.queued_spans.first
    assert_equal 'a3ce929d0e0e4736', span[:t]
    assert_equal '00f067aa0ba902b7', span[:p]
    assert_equal 'entry', span[:data][:sqs][:sort]
  end

  def test_start_trace_with_w3c_traceparent_and_tracestate
    message = OpenStruct.new(
      queue_url: 'http://example.com',
      message_attributes: {
        'traceparent' => OpenStruct.new(string_value: '00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01'),
        'tracestate' => OpenStruct.new(string_value: 'in=1234567890abcdef;fedcba0987654321')
      }
    )

    @middleware.call(nil, nil, message, nil) {}

    span = ::Instana.processor.queued_spans.first
    assert_equal '1234567890abcdef', span[:t]
    assert_equal 'fedcba0987654321', span[:p]
  end

  def test_start_trace_with_w3c_traceparent_unsampled
    message = OpenStruct.new(
      queue_url: 'http://example.com',
      message_attributes: {
        'traceparent' => OpenStruct.new(string_value: '00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-00')
      }
    )

    @middleware.call(nil, nil, message, nil) {}

    # Since level is 0 (unsampled), no recording span should be queued
    assert_empty ::Instana.processor.queued_spans
  end
end
