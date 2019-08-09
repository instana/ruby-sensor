require 'test_helper'

class GrpcTest < Minitest::Test
  def client_stub
    PingPongService::Stub.new('127.0.0.1:50051', :this_channel_is_insecure)
  end

  # The order of traces are non-deterministic, could not predict
  # which trace is server or client. This method is to choose the
  # right trace based on span's name
  def differentiate_trace(traces)
    trying_client = traces[0]
    trying_server = traces[1]

    try_successfully = trying_client.spans.any? do |span|
      span.name == :'rpc-client'
    end

    if try_successfully
      [trying_client, trying_server]
    else
      [trying_server, trying_client]
    end
  end

  def assert_client_trace(client_trace, call: '', call_type: '', error: nil)
    assert_equal 2, client_trace.spans.length
    spans = client_trace.spans.to_a
    first_span = spans[0]
    second_span = spans[1]

    # Span name validation
    assert_equal :sdk, first_span[:n]
    assert_equal :rpctests, first_span[:data][:sdk][:name]
    assert_equal :'rpc-client', second_span[:n]

    # first_span is the parent of second_span
    assert_equal first_span.id, second_span[:p]

    data = second_span[:data]
    assert_equal '127.0.0.1:50051', data[:rpc][:host]
    assert_equal :grpc, data[:rpc][:flavor]
    assert_equal call, data[:rpc][:call]
    assert_equal call_type, data[:rpc][:call_type]

    if error
      assert_equal true, data[:rpc][:error]
      assert_equal "2:RuntimeError: #{error}", data[:log][:message]
    end
  end

  def assert_server_trace(server_trace, call: '', call_type: '', error: nil)
    assert_equal 1, server_trace.spans.length
    span = server_trace.spans.to_a.first

    # Span name validation
    assert_equal :'rpc-server', span[:n]

    data = span[:data]
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

    Instana.tracer.start_or_continue_trace(:rpctests) do
      response = client_stub.ping(
        PingPongService::PingRequest.new(message: 'Hello World')
      )
    end
    sleep 1

    assert 'Hello World', response.message

    # Pause for a split second to allow traces to be queued
    sleep 0.2

    assert_equal 2, ::Instana.processor.queue_count
    client_trace, server_trace = differentiate_trace(
      Instana.processor.queued_traces
    )

    assert_client_trace(
      client_trace,
      call: '/PingPongService/Ping',
      call_type: :request_response
    )

    assert_server_trace(
      server_trace,
      call: '/PingPongService/Ping',
      call_type: :request_response
    )
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

    assert_equal 2, ::Instana.processor.queue_count
    client_trace, server_trace = differentiate_trace(
      Instana.processor.queued_traces
    )

    assert_client_trace(
      client_trace,
      call: '/PingPongService/PingWithClientStream',
      call_type: :client_streamer
    )

    assert_server_trace(
      server_trace,
      call: '/PingPongService/PingWithClientStream',
      call_type: :client_streamer
    )
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

    assert_equal 2, ::Instana.processor.queue_count
    client_trace, server_trace = differentiate_trace(
      Instana.processor.queued_traces
    )

    assert_client_trace(
      client_trace,
      call: '/PingPongService/PingWithServerStream',
      call_type: :server_streamer
    )

    assert_server_trace(
      server_trace,
      call: '/PingPongService/PingWithServerStream',
      call_type: :server_streamer
    )
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

    assert_equal 2, ::Instana.processor.queue_count
    client_trace, server_trace = differentiate_trace(
      Instana.processor.queued_traces
    )

    assert_client_trace(
      client_trace,
      call: '/PingPongService/PingWithBidiStream',
      call_type: :bidi_streamer
    )

    assert_server_trace(
      server_trace,
      call: '/PingPongService/PingWithBidiStream',
      call_type: :bidi_streamer
    )
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

    assert_equal 2, ::Instana.processor.queue_count
    client_trace, server_trace = differentiate_trace(
      Instana.processor.queued_traces
    )

    assert_client_trace(
      client_trace,
      call: '/PingPongService/FailToPing',
      call_type: :request_response,
      error: 'Unexpected failed'
    )
    assert_server_trace(
      server_trace,
      call: '/PingPongService/FailToPing',
      call_type: :request_response,
      error: 'Unexpected failed'
    )
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

    assert_equal 2, ::Instana.processor.queue_count
    client_trace, server_trace = differentiate_trace(
      Instana.processor.queued_traces
    )

    assert_client_trace(
      client_trace,
      call: '/PingPongService/FailToPingWithClientStream',
      call_type: :client_streamer,
      error: 'Unexpected failed'
    )

    assert_server_trace(
      server_trace,
      call: '/PingPongService/FailToPingWithClientStream',
      call_type: :client_streamer,
      error: 'Unexpected failed'
    )
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

    assert_equal 2, ::Instana.processor.queue_count
    client_trace, server_trace = differentiate_trace(
      Instana.processor.queued_traces
    )

    assert_client_trace(
      client_trace,
      call: '/PingPongService/FailToPingWithServerStream',
      call_type: :server_streamer
    )

    assert_server_trace(
      server_trace,
      call: '/PingPongService/FailToPingWithServerStream',
      call_type: :server_streamer,
      error: 'Unexpected failed'
    )
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

    assert_equal 2, ::Instana.processor.queue_count
    client_trace, server_trace = differentiate_trace(
      Instana.processor.queued_traces
    )

    assert_client_trace(
      client_trace,
      call: '/PingPongService/FailToPingWithBidiStream',
      call_type: :bidi_streamer
    )

    assert_server_trace(
      server_trace,
      call: '/PingPongService/FailToPingWithBidiStream',
      call_type: :bidi_streamer,
      error: 'Unexpected failed'
    )
  end
end
