# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2017

require 'test_helper'
require 'support/apps/grpc/boot'

class GrpcTest < Minitest::Test
  def client_stub
    PingPongService::Stub.new('127.0.0.1:50051', :this_channel_is_insecure)
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

  def test_config_defaults
    assert ::Instana.config[:grpc].is_a?(Hash)
    assert ::Instana.config[:grpc].key?(:enabled)
    assert_equal true, ::Instana.config[:grpc][:enabled]

    client_activator = ::Instana::Activators::GrpcClient.new
    server_activator = ::Instana::Activators::GrpcServer.new
    assert_equal true, client_activator.can_instrument?
    assert_equal true, server_activator.can_instrument?
  end

  def test_instrumentation_disabled
    ::Instana.config[:grpc][:enabled] = false

    client_activator = ::Instana::Activators::GrpcClient.new
    server_activator = ::Instana::Activators::GrpcServer.new
    assert_equal false, client_activator.can_instrument?
    assert_equal false, server_activator.can_instrument?
  end

  def test_request_response
    clear_all!
    response = nil

    Instana.tracer.start_or_continue_trace(:rpctests) do
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

  def test_client_streamer
    clear_all!
    response = nil

    Instana.tracer.start_or_continue_trace(:rpctests) do
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

    Instana.tracer.start_or_continue_trace(:rpctests) do
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

    Instana.tracer.start_or_continue_trace(:rpctests) do
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
    Instana.tracer.start_or_continue_trace(:rpctests) do
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
    Instana.tracer.start_or_continue_trace(:rpctests) do
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
    Instana.tracer.start_or_continue_trace(:rpctests) do
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
    Instana.tracer.start_or_continue_trace(:rpctests) do
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
end
