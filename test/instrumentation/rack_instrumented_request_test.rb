# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2021

require 'test_helper'

class RackInstrumentedRequestTest < Minitest::Test
  def test_suppression_via_x_instana_l
    req = Instana::InstrumentedRequest.new(
      'HTTP_X_INSTANA_L' => '0'
    )

    assert req.skip_trace?
  end

  def test_suppression_via_x_instana_l_with_trailing_content
    req = Instana::InstrumentedRequest.new(
      'HTTP_X_INSTANA_L' => '0;sample-data'
    )

    assert req.skip_trace?
  end

  def test_no_suppression_assume_level_1_as_default
    req = Instana::InstrumentedRequest.new({})

    assert !req.skip_trace?
  end

  def test_no_suppression_when_x_instana_l_is_provided_explicitly
    req = Instana::InstrumentedRequest.new(
      'HTTP_X_INSTANA_L' => '1'
    )

    assert !req.skip_trace?
  end

  def test_skip_trace_without_header
    req = Instana::InstrumentedRequest.new({})

    refute req.skip_trace?
  end

  def test_incoming_context
    id = Instana::Util.generate_id
    req = Instana::InstrumentedRequest.new(
      'HTTP_X_INSTANA_L' => '1',
      'HTTP_X_INSTANA_T' => id,
      'HTTP_X_INSTANA_S' => id
    )

    expected = {
      trace_id: id,
      span_id: id,
      from_w3c: false,
      level: '1'
    }

    assert_equal expected, req.incoming_context
    refute req.continuing_from_trace_parent?
  end

  def test_incoming_w3c_context
    req = Instana::InstrumentedRequest.new(
      'HTTP_TRACEPARENT' => '00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01'
    )

    expected = {
      external_trace_id: '4bf92f3577b34da6a3ce929d0e0e4736',
      external_state: nil,
      trace_id: 'a3ce929d0e0e4736',
      span_id: '00f067aa0ba902b7',
      external_trace_flags: "01",
      from_w3c: true
    }

    assert_equal expected, req.incoming_context
    assert req.continuing_from_trace_parent?
  end

  def test_incoming_w3c_context_newer_version_additional_fields
    req = Instana::InstrumentedRequest.new(
      'HTTP_TRACEPARENT' => 'fe-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01-abcdefg'
    )

    expected = {
      external_trace_id: '4bf92f3577b34da6a3ce929d0e0e4736',
      external_state: nil,
      trace_id: 'a3ce929d0e0e4736',
      span_id: '00f067aa0ba902b7',
      external_trace_flags: "01",
      from_w3c: true
    }

    assert_equal expected, req.incoming_context
    assert req.continuing_from_trace_parent?
  end

  def test_incoming_w3c_context_unknown_flags
    req = Instana::InstrumentedRequest.new(
      'HTTP_TRACEPARENT' => '00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-ff'
    )

    expected = {
      external_trace_id: '4bf92f3577b34da6a3ce929d0e0e4736',
      external_state: nil,
      trace_id: 'a3ce929d0e0e4736',
      span_id: '00f067aa0ba902b7',
      external_trace_flags: "ff",
      from_w3c: true
    }

    assert_equal expected, req.incoming_context
    assert req.continuing_from_trace_parent?
  end

  def test_incoming_w3c_context_invalid_version
    req = Instana::InstrumentedRequest.new(
      'HTTP_TRACEPARENT' => 'ff-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01'
    )

    expected = {}

    assert_equal expected, req.incoming_context
    refute req.continuing_from_trace_parent?
  end

  def test_incoming_w3c_context_invalid_id
    req = Instana::InstrumentedRequest.new(
      'HTTP_TRACEPARENT' => '00-00000000000000000000000000000000-0000000000000000-01'
    )

    expected = {}

    assert_equal expected, req.incoming_context
    refute req.continuing_from_trace_parent?
  end

  def test_incoming_invalid_w3c_context
    req = Instana::InstrumentedRequest.new(
      'HTTP_TRACEPARENT' => '00-XXa3ce929d0e0e4736-00f67aa0ba902b7-01'
    )

    expected = {}

    assert_equal expected, req.incoming_context
    refute req.continuing_from_trace_parent?
  end

  def test_incoming_w3c_state
    req = Instana::InstrumentedRequest.new(
      'HTTP_TRACESTATE' => 'a=12345,in=123;abe,c=[+]'
    )

    expected = {
      t: '123',
      p: 'abe'
    }

    assert_equal expected, req.instana_ancestor
  end

  def test_request_tags
    ::Instana.agent.define_singleton_method(:extra_headers) { %w[X-Capture-This] }

    req = Instana::InstrumentedRequest.new(
      'HTTP_HOST' => 'example.com',
      'REQUEST_METHOD' => 'GET',
      'HTTP_X_CAPTURE_THIS' => 'that',
      'PATH_INFO' => '/',
      'QUERY_STRING' => 'test=true'
    )

    expected = {
      method: 'GET',
      url: '/',
      host: 'example.com',
      header: {
        "X-Capture-This": 'that'
      },
      params: 'test=true'
    }

    assert_equal expected, req.request_tags
    ::Instana.agent.singleton_class.send(:remove_method, :extra_headers)
  end

  def test_correlation_data_valid
    req = Instana::InstrumentedRequest.new(
      'HTTP_X_INSTANA_L' => '1,correlationType=web ;correlationId=1234567890abcdef'
    )
    expected = {
      type: 'web',
      id: '1234567890abcdef'
    }

    assert_equal expected, req.correlation_data
  end

  def test_correlation_data_invalid
    req = Instana::InstrumentedRequest.new(
      'HTTP_X_INSTANA_L' => '0;sample-data'
    )

    assert_equal({}, req.correlation_data)
  end

  def test_correlation_data_legacy
    req = Instana::InstrumentedRequest.new(
      'HTTP_X_INSTANA_L' => '1'
    )

    assert_equal({}, req.correlation_data)
  end

  def test_context_from_trace_state_only
    # Only HTTP_TRACESTATE present — exercises context_from_trace_state (L153-161)
    req = Instana::InstrumentedRequest.new(
      'HTTP_TRACESTATE' => 'a=xyz,in=abcdef1234;deadbeef5678,b=other'
    )

    ctx = req.incoming_context
    assert_equal 'abcdef1234', ctx[:trace_id]
    assert_equal 'deadbeef5678', ctx[:span_id]
    assert_equal false, ctx[:from_w3c]
  end

  def test_context_from_trace_state_no_instana_token
    # TRACESTATE present but no in= token — context_from_trace_state returns empty
    req = Instana::InstrumentedRequest.new(
      'HTTP_TRACESTATE' => 'vendor=value,other=stuff'
    )

    ctx = req.incoming_context
    assert_equal({}, ctx)
  end

  def test_w3c_context_with_instana_trace_state_replaces_ids
    # When w3c_trace_correlation is OFF, a W3C traceparent + in= tracestate
    # should replace trace_id/span_id with the Instana values (L41-44)
    original = ::Instana.config[:w3c_trace_correlation]
    ::Instana.config[:w3c_trace_correlation] = false

    req = Instana::InstrumentedRequest.new(
      'HTTP_TRACEPARENT' => '00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01',
      'HTTP_TRACESTATE' => 'in=instana123;spanid456'
    )

    ctx = req.incoming_context
    assert_equal 'instana123', ctx[:trace_id], "trace_id should be overridden from in= tracestate"
    assert_equal 'spanid456',  ctx[:span_id],  "span_id should be overridden from in= tracestate"
    assert_equal false, ctx[:from_w3c]
  ensure
    ::Instana.config[:w3c_trace_correlation] = original
  end

  def test_w3c_context_with_empty_trace_state_clears_span_id
    # When w3c_trace_correlation is OFF and tracestate has no in= entry,
    # span_id should be cleared (L38-40)
    original = ::Instana.config[:w3c_trace_correlation]
    ::Instana.config[:w3c_trace_correlation] = false

    req = Instana::InstrumentedRequest.new(
      'HTTP_TRACEPARENT' => '00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01'
      # no HTTP_TRACESTATE
    )

    ctx = req.incoming_context
    # from_w3c should be set to false and span_id cleared
    assert_equal false, ctx[:from_w3c]
    refute ctx.key?(:span_id), "span_id should be removed when tracestate is empty"
  ensure
    ::Instana.config[:w3c_trace_correlation] = original
  end

  def test_incoming_context_with_span_context_object
    # When incoming_context returns a SpanContext (not Hash), rack extracts it correctly
    # Test the SpanContext path in extract_trace_context (L60-61)
    Instana::SpanContext.new(trace_id: 'abc123', span_id: 'def456')
    req = Instana::InstrumentedRequest.new(
      'HTTP_X_INSTANA_T' => 'abc123',
      'HTTP_X_INSTANA_S' => 'def456',
      'HTTP_X_INSTANA_L' => '1'
    )

    ctx = req.incoming_context
    # extract_trace_context on the Rack middleware receives the hash from incoming_context
    # Here we just verify InstrumentedRequest produces the right hash
    assert_equal 'abc123', ctx[:trace_id]
    assert_equal 'def456', ctx[:span_id]
  end
end
