require 'test_helper'

class GrpcTest < Minitest::Test
  def client_stub
    PingPongService::Stub.new('127.0.0.1:50051', :this_channel_is_insecure)
  end

  def assert_client_trace(client_trace, call:, call_type:)
    assert_equal 2, client_trace.spans.count
    spans = client_trace.spans.to_a
    first_span = spans[0]
    second_span = spans[1]

    # Span name validation
    assert_equal :sdk, first_span[:n]
    assert_equal :sdk, second_span[:n]

    # first_span is the parent of second_span
    assert_equal first_span.id, second_span[:p]

    # data keys/values
    assert_equal :'rpc-client', second_span[:data][:sdk][:name]

    data = second_span[:data][:sdk][:custom]
    assert_equal '127.0.0.1:50051', data[:rpc][:host]
    assert_equal :grpc, data[:rpc][:flavor]
    assert_equal call, data[:rpc][:call]
    assert_equal call_type, data[:rpc][:call_type]
  end

  def assert_server_trace(server_trace, call:, call_type:)
    assert_equal 1, server_trace.spans.count
    span = server_trace.spans.to_a.first

    # Span name validation
    assert_equal :sdk, span[:n]

    # data keys/values
    assert_equal :'rpc-server', span[:data][:sdk][:name]

    data = span[:data][:sdk][:custom]
    assert_equal :grpc, data[:rpc][:flavor]
    assert_equal call, data[:rpc][:call]
    assert_equal call_type, data[:rpc][:call_type]
  end

  def test_request_response
    clear_all!
    response = nil

    Instana.tracer.start_or_continue_trace(:'rpc-client') do
      response = client_stub.ping(
        PingPongService::PingRequest.new(message: 'Hello World')
      )
    end

    assert 'Hello World', response.message

    assert_equal 2, ::Instana.processor.queue_count
    traces = Instana.processor.queued_traces

    server_trace = traces[0]
    client_trace = traces[1]

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

    Instana.tracer.start_or_continue_trace(:'rpc-client') do
      response = client_stub.ping_with_client_stream(
        (0..5).map do |index|
          PingPongService::PingRequest.new(message: index.to_s)
        end
      )
    end

    assert '01234', response.message

    assert_equal 2, ::Instana.processor.queue_count
    traces = Instana.processor.queued_traces

    server_trace = traces[0]
    client_trace = traces[1]

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

    Instana.tracer.start_or_continue_trace(:'rpc-client') do
      responses = client_stub.ping_with_server_stream(
        PingPongService::PingRequest.new(message: 'Hello World')
      )
    end

    assert %w(0 1 2 3 4), responses.map(&:message)

    assert_equal 2, ::Instana.processor.queue_count
    traces = Instana.processor.queued_traces

    client_trace = traces[0]
    server_trace = traces[1]

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

    Instana.tracer.start_or_continue_trace(:'rpc-client') do
      responses = client_stub.ping_with_bidi_stream(
        (0..5).map do |index|
          PingPongService::PingRequest.new(message: (index * 2).to_s)
        end
      )
    end

    assert %w(0 2 4 6 8), responses.to_a.map(&:message)

    assert_equal 2, ::Instana.processor.queue_count
    traces = Instana.processor.queued_traces

    client_trace = traces[0]
    server_trace = traces[1]

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
end
