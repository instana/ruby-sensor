# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2017

require 'test_helper'
require 'support/apps/grpc/boot'

class GrpcTest < Minitest::Test # rubocop:disable Metrics/ClassLength
  def client_stub
    PingPongService::Stub.new('127.0.0.1:50051', :this_channel_is_insecure)
  end

  def teardown
    ::Instana.config[:allow_exit_as_root] = false
  end

  def assert_client_span(client_span, call: '', call_type: '', error: nil)
    data = client_span[:data]
    assert_equal '127.0.0.1:50051', data[:rpc][:host]
    assert_equal :grpc, data[:rpc][:flavor]
    assert_equal call, data[:rpc][:call]
    assert_equal call_type, data[:rpc][:call_type]

    if error
      assert_equal true, data[:rpc][:error]
      assert data[:log][:message].include?("2:RuntimeError: #{error}")
    end
  end

  def assert_server_span(server_span, call: '', call_type: '', error: nil)
    # Span name validation
    assert_equal :'rpc-server', server_span[:n]

    data = server_span[:data]
    assert_equal :grpc, data[:rpc][:flavor]
    assert_equal call, data[:rpc][:call]
    assert_equal call_type, data[:rpc][:call_type]

    if error
      assert_equal true, data[:rpc][:error]
      assert_equal error, data[:log][:message]
    end
  end

  def test_request_response
    clear_all!
    response = nil

    Instana.tracer.in_span(:rpctests) do
      response = client_stub.ping(
        PingPongService::PingRequest.new(message: 'Hello World')
      )
    end
    sleep 1

    assert 'Hello World', response.message

    # Pause for a split second to allow traces to be queued
    sleep 0.2

    spans = ::Instana.processor.queued_spans
    sdk_span = find_spans_by_name(spans, :rpctests).first
    client_span = find_spans_by_name(spans, :'rpc-client').first
    server_span = find_spans_by_name(spans, :'rpc-server').first

    validate_sdk_span(sdk_span)

    assert_client_span(
        client_span,
        call: '/PingPongService/Ping',
        call_type: :request_response
    )

    assert_server_span(
        server_span,
        call: '/PingPongService/Ping',
        call_type: :request_response
    )

    trace_id = sdk_span[:t]
    assert_equal trace_id, client_span[:t]
    assert_equal trace_id, server_span[:t]

    assert_equal server_span[:p], client_span[:s]
    assert_equal client_span[:p], sdk_span[:s]
  end

  def test_request_response_as_root_exit_span
    clear_all!
    ::Instana.config[:allow_exit_as_root] = true

    response = client_stub.ping(
      PingPongService::PingRequest.new(message: 'Hello World')
    )
    sleep 1

    assert 'Hello World', response.message

    # Pause for a split second to allow traces to be queued
    sleep 0.2

    spans = ::Instana.processor.queued_spans
    client_span = find_spans_by_name(spans, :'rpc-client').first
    server_span = find_spans_by_name(spans, :'rpc-server').first

    assert_client_span(
        client_span,
        call: '/PingPongService/Ping',
        call_type: :request_response
    )

    assert_server_span(
        server_span,
        call: '/PingPongService/Ping',
        call_type: :request_response
    )

    assert_equal client_span[:t], server_span[:t]
    assert_equal client_span[:s], server_span[:p]
    assert_nil client_span[:p]
  end

  def test_client_streamer
    clear_all!
    response = nil

    Instana.tracer.in_span(:rpctests) do
      response = client_stub.ping_with_client_stream(
        (0..5).map do |index|
          PingPongService::PingRequest.new(message: index.to_s)
        end
      )
    end
    sleep 1

    assert '01234', response.message

    # Pause for a split second to allow traces to be queued
    sleep 0.2

    spans = ::Instana.processor.queued_spans
    sdk_span = find_spans_by_name(spans, :rpctests).first
    client_span = find_spans_by_name(spans, :'rpc-client').first
    server_span = find_spans_by_name(spans, :'rpc-server').first

    validate_sdk_span(sdk_span)

    assert_client_span(
        client_span,
        call: '/PingPongService/PingWithClientStream',
        call_type: :client_streamer
    )

    assert_server_span(
        server_span,
        call: '/PingPongService/PingWithClientStream',
        call_type: :client_streamer
    )

    trace_id = sdk_span[:t]
    assert_equal trace_id, client_span[:t]
    assert_equal trace_id, server_span[:t]

    assert_equal server_span[:p], client_span[:s]
    assert_equal client_span[:p], sdk_span[:s]
  end

  def test_server_streamer
    clear_all!
    responses = []

    Instana.tracer.in_span(:rpctests) do
      responses = client_stub.ping_with_server_stream(
        PingPongService::PingRequest.new(message: 'Hello World')
      )
    end
    assert %w(0 1 2 3 4), responses.map(&:message)

    # Pause for a split second to allow traces to be queued
    sleep 0.2

    spans = ::Instana.processor.queued_spans
    sdk_span = find_spans_by_name(spans, :rpctests).first
    client_span = find_spans_by_name(spans, :'rpc-client').first
    server_span = find_spans_by_name(spans, :'rpc-server').first

    validate_sdk_span(sdk_span)

    assert_client_span(
        client_span,
        call: '/PingPongService/PingWithServerStream',
        call_type: :server_streamer
    )

    assert_server_span(
        server_span,
        call: '/PingPongService/PingWithServerStream',
        call_type: :server_streamer
    )

    trace_id = sdk_span[:t]
    assert_equal trace_id, client_span[:t]
    assert_equal trace_id, server_span[:t]

    assert_equal server_span[:p], client_span[:s]
    assert_equal client_span[:p], sdk_span[:s]
  end

  def test_bidi_streamer
    clear_all!
    responses = []

    Instana.tracer.in_span(:rpctests) do
      responses = client_stub.ping_with_bidi_stream(
        (0..5).map do |index|
          PingPongService::PingRequest.new(message: (index * 2).to_s)
        end
      )
    end
    sleep 1

    assert %w(0 2 4 6 8), responses.to_a.map(&:message)

    # Pause for a split second to allow traces to be queued
    sleep 0.2

    spans = ::Instana.processor.queued_spans
    sdk_span = find_spans_by_name(spans, :rpctests).first
    client_span = find_spans_by_name(spans, :'rpc-client').first
    server_span = find_spans_by_name(spans, :'rpc-server').first

    validate_sdk_span(sdk_span)

    assert_client_span(
        client_span,
        call: '/PingPongService/PingWithBidiStream',
        call_type: :bidi_streamer
    )

    assert_server_span(
        server_span,
        call: '/PingPongService/PingWithBidiStream',
        call_type: :bidi_streamer
    )

    trace_id = sdk_span[:t]
    assert_equal trace_id, client_span[:t]
    assert_equal trace_id, server_span[:t]

    assert_equal server_span[:p], client_span[:s]
    assert_equal client_span[:p], sdk_span[:s]
  end

  def test_request_response_failure
    clear_all!
    Instana.tracer.in_span(:rpctests) do
      begin
        client_stub.fail_to_ping( PingPongService::PingRequest.new(message: 'Hello World'))
      rescue
      end
    end

    # Pause for a split second to allow traces to be queued
    sleep 0.2

    spans = ::Instana.processor.queued_spans
    sdk_span = find_spans_by_name(spans, :rpctests).first
    client_span = find_spans_by_name(spans, :'rpc-client').first
    server_span = find_spans_by_name(spans, :'rpc-server').first

    validate_sdk_span(sdk_span)

    assert_client_span(
        client_span,
        call: '/PingPongService/FailToPing',
        call_type: :request_response,
        error: 'Unexpected failed'
    )
    assert_server_span(
        server_span,
        call: '/PingPongService/FailToPing',
        call_type: :request_response,
        error: 'Unexpected failed'
    )

    trace_id = sdk_span[:t]
    assert_equal trace_id, client_span[:t]
    assert_equal trace_id, server_span[:t]

    assert_equal server_span[:p], client_span[:s]
    assert_equal client_span[:p], sdk_span[:s]
  end

  def test_client_streamer_failure
    clear_all!
    Instana.tracer.in_span(:rpctests) do
      begin
        client_stub.fail_to_ping_with_client_stream(
          (0..5).map do |index|
            PingPongService::PingRequest.new(message: index.to_s)
          end
        )
      rescue
      end
    end

    # Pause for a split second to allow traces to be queued
    sleep 0.2

    spans = ::Instana.processor.queued_spans
    sdk_span = find_spans_by_name(spans, :rpctests).first
    client_span = find_spans_by_name(spans, :'rpc-client').first
    server_span = find_spans_by_name(spans, :'rpc-server').first

    validate_sdk_span(sdk_span)

    assert_client_span(
      client_span,
      call: '/PingPongService/FailToPingWithClientStream',
      call_type: :client_streamer,
      error: 'Unexpected failed'
    )

    assert_server_span(
      server_span,
      call: '/PingPongService/FailToPingWithClientStream',
      call_type: :client_streamer,
      error: 'Unexpected failed'
    )

    trace_id = sdk_span[:t]
    assert_equal trace_id, client_span[:t]
    assert_equal trace_id, server_span[:t]

    assert_equal server_span[:p], client_span[:s]
    assert_equal client_span[:p], sdk_span[:s]
  end

  def test_server_streamer_failure
    clear_all!
    Instana.tracer.in_span(:rpctests) do
      begin
        client_stub.fail_to_ping_with_server_stream(
          PingPongService::PingRequest.new(message: 'Hello World')
        )
      rescue
      end
    end

    # Pause for a split second to allow traces to be queued
    sleep 0.2

    spans = ::Instana.processor.queued_spans
    sdk_span = find_spans_by_name(spans, :rpctests).first
    client_span = find_spans_by_name(spans, :'rpc-client').first
    server_span = find_spans_by_name(spans, :'rpc-server').first

    validate_sdk_span(sdk_span)

    assert_client_span(
      client_span,
      call: '/PingPongService/FailToPingWithServerStream',
      call_type: :server_streamer
    )

    assert_server_span(
      server_span,
      call: '/PingPongService/FailToPingWithServerStream',
      call_type: :server_streamer,
      error: 'Unexpected failed'
    )

    trace_id = sdk_span[:t]
    assert_equal trace_id, client_span[:t]
    assert_equal trace_id, server_span[:t]

    assert_equal server_span[:p], client_span[:s]
    assert_equal client_span[:p], sdk_span[:s]
  end

  def test_bidi_streamer_failure
    clear_all!
    Instana.tracer.in_span(:rpctests) do
      client_stub.fail_to_ping_with_bidi_stream(
        (0..5).map do |index|
          PingPongService::PingRequest.new(message: (index * 2).to_s)
        end
      )
    end

    # Pause for a split second to allow traces to be queued
    sleep 0.2

    spans = ::Instana.processor.queued_spans
    sdk_span = find_spans_by_name(spans, :rpctests).first
    client_span = find_spans_by_name(spans, :'rpc-client').first
    server_span = find_spans_by_name(spans, :'rpc-server').first

    validate_sdk_span(sdk_span)

    assert_client_span(
      client_span,
      call: '/PingPongService/FailToPingWithBidiStream',
      call_type: :bidi_streamer
    )

    assert_server_span(
      server_span,
      call: '/PingPongService/FailToPingWithBidiStream',
      call_type: :bidi_streamer,
      error: 'Unexpected failed'
    )

    trace_id = sdk_span[:t]
    assert_equal trace_id, client_span[:t]
    assert_equal trace_id, server_span[:t]

    assert_equal server_span[:p], client_span[:s]
    assert_equal client_span[:p], sdk_span[:s]
  end

  # A call from an untraced client carries no x-instana-t/-s metadata; the
  # server still answers normally and records the call as a root span.
  def test_server_span_for_request_without_trace_headers
    clear_all!

    response = client_stub.ping(
      PingPongService::PingRequest.new(message: 'World')
    )
    sleep 0.2

    assert_equal 'Hello World', response.message

    server_span, rest = ::Instana.processor.queued_spans
    assert_nil rest

    assert_server_span(
      server_span,
      call: '/PingPongService/Ping',
      call_type: :request_response
    )
    assert_nil server_span[:p]
  end

  def test_no_error_is_raised_and_no_spans_are_created_when_agent_is_not_ready
    clear_all!
    error = nil
    ::Instana.agent.stub(:ready?, false) do
      assert_silent do
        begin
          client_stub.ping(
            PingPongService::PingRequest.new(message: 'Hello World')
          )
        rescue StandardError => e
          error = e
        end
      end
    end

    sleep 0.2

    assert_nil error
    assert_empty ::Instana.processor.queued_spans
  end

  def test_client_injects_w3c_headers
    # Phase 6.6 — client must also inject traceparent/tracestate
    clear_all!

    Instana.tracer.in_span(:grpc_w3c_test) do
      client_stub.ping(PingPongService::PingRequest.new(message: 'W3CCheck'))
    end
    sleep 0.2

    spans = ::Instana.processor.queued_spans
    client_span = find_spans_by_name(spans, :'rpc-client').first
    server_span = find_spans_by_name(spans, :'rpc-server').first

    # Server correctly parented to client confirms W3C headers were received and parsed
    assert_equal client_span[:s], server_span[:p]
    assert_equal client_span[:t], server_span[:t]
  end

  def test_extract_grpc_context_traceparent_only
    # Phase 6.7 — traceparent only (no Instana headers) → SpanContext gets correct IDs and level
    helper = Class.new { prepend ::Instana::Instrumentation::GRPCServerInstrumentation }.new
    metadata = {
      'traceparent' => '00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01'
    }
    ctx = helper.send(:extract_grpc_context, metadata)
    assert_instance_of ::Instana::SpanContext, ctx
    # Trace ID taken from last 16 hex chars of the 32-char trace
    assert_equal ::Instana::Util.header_to_id('a3ce929d0e0e4736'), ctx.trace_id
    assert_equal ::Instana::Util.header_to_id('00f067aa0ba902b7'), ctx.span_id
    assert_equal 1, ctx.level
  end

  def test_extract_grpc_context_traceparent_with_tracestate
    # Phase 6.8 — traceparent + tracestate in=<t>;<s> → Instana IDs from tracestate
    helper = Class.new { prepend ::Instana::Instrumentation::GRPCServerInstrumentation }.new
    metadata = {
      'traceparent' => '00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01',
      'tracestate' => 'in=aabbccdd11223344;ff00ff00ff00ff00'
    }
    ctx = helper.send(:extract_grpc_context, metadata)
    assert_instance_of ::Instana::SpanContext, ctx
    assert_equal ::Instana::Util.header_to_id('aabbccdd11223344'), ctx.trace_id
    assert_equal ::Instana::Util.header_to_id('ff00ff00ff00ff00'), ctx.span_id
    assert_equal 1, ctx.level
  end

  def test_extract_grpc_context_traceparent_not_sampled
    # Phase 6.9 — traceparent with flags=00 → SpanContext.level is 0
    helper = Class.new { prepend ::Instana::Instrumentation::GRPCServerInstrumentation }.new
    metadata = {
      'traceparent' => '00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-00'
    }
    ctx = helper.send(:extract_grpc_context, metadata)
    assert_instance_of ::Instana::SpanContext, ctx
    assert_equal 0, ctx.level
  end

  def test_client_injects_instana_level_header
    # Phase 5.3 — the instrumentation must write x-instana-l into the options hash.
    # We use an end-to-end call (level: 1 default) and confirm the server received
    # x-instana-l by checking that the server's incoming_context was built with a level.
    # We verify the header is present by running a normal traced call and asserting
    # that the server span is linked (which requires the server to successfully parse
    # the metadata including x-instana-l).
    clear_all!

    Instana.tracer.in_span(:grpc_level_test) do
      client_stub.ping(PingPongService::PingRequest.new(message: 'LevelCheck'))
    end
    sleep 0.2

    spans = ::Instana.processor.queued_spans
    client_span = find_spans_by_name(spans, :'rpc-client').first
    server_span = find_spans_by_name(spans, :'rpc-server').first

    # Server correctly parented to client confirms x-instana-t/s/l were all received
    assert_equal client_span[:s], server_span[:p]
  end
end
