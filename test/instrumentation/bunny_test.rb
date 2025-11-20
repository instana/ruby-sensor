# (c) Copyright IBM Corp. 2025

require 'test_helper'

class BunnyTest < Minitest::Test
  def setup
    skip unless defined?(::Bunny)

    @connection = ::Bunny.new(host: ENV['RABBITMQ_HOST'] || 'localhost')
    begin
      @connection.start
    rescue Bunny::TCPConnectionFailedForAllHosts, Bunny::TCPConnectionFailed => e
      skip "RabbitMQ is not running: #{e.message}"
    end
    @channel = @connection.create_channel
    @exchange = @channel.default_exchange
    @queue = @channel.queue('instana.test.queue', auto_delete: true)
  end

  def teardown
    return unless defined?(::Bunny)

    @queue.delete if @queue && @channel&.open?
    @channel.close if @channel&.open?
    @connection.close if @connection&.open?
  end

  def test_config_defaults
    assert ::Instana.config[:bunny].is_a?(Hash)
    assert ::Instana.config[:bunny].key?(:enabled)
    assert_equal true, ::Instana.config[:bunny][:enabled]
  end

  def test_publish_with_tracing
    skip unless defined?(::Bunny)
    clear_all!

    ::Instana.tracer.in_span(:rabbitmq_test) do
      @exchange.publish('test message', routing_key: @queue.name)
    end

    spans = ::Instana.processor.queued_spans
    assert_equal 2, spans.length

    rabbitmq_span = spans[0]
    test_span = spans[1]

    # Verify parent-child relationship
    assert_equal test_span[:s], rabbitmq_span[:p]

    # Verify RabbitMQ span details
    assert_equal :rabbitmq, rabbitmq_span[:n]
    assert_equal 'publish', rabbitmq_span[:data][:rabbitmq][:sort]
    assert_equal @queue.name, rabbitmq_span[:data][:rabbitmq][:key]
    assert_equal 'default', rabbitmq_span[:data][:rabbitmq][:exchange]
    assert rabbitmq_span[:data][:rabbitmq][:address]
  end

  def test_publish_injects_trace_headers
    skip unless defined?(::Bunny)
    clear_all!

    ::Instana.tracer.in_span(:rabbitmq_test) do
      @exchange.publish('test message', routing_key: @queue.name)
    end

    # Retrieve the message
    delivery_info, properties, _payload = @queue.pop

    refute_nil delivery_info
    refute_nil properties
    refute_nil properties.headers

    # Verify trace context headers are present
    assert properties.headers['X-Instana-T']
    assert properties.headers['X-Instana-S']
    assert properties.headers['X-Instana-L']
  end

  def test_publish_without_tracing
    skip unless defined?(::Bunny)
    clear_all!

    # Publish without active trace
    @exchange.publish('test message', routing_key: @queue.name)

    spans = ::Instana.processor.queued_spans
    assert_equal 0, spans.length

    # Message should still be delivered
    delivery_info, _properties, payload = @queue.pop
    refute_nil delivery_info
    assert_equal 'test message', payload
  end

  def test_publish_with_custom_exchange
    skip unless defined?(::Bunny)
    clear_all!

    custom_exchange = @channel.topic('instana.test.exchange', auto_delete: true)
    @queue.bind(custom_exchange, routing_key: 'test.key')

    ::Instana.tracer.in_span(:rabbitmq_test) do
      custom_exchange.publish('test message', routing_key: 'test.key')
    end

    spans = ::Instana.processor.queued_spans
    assert_equal 2, spans.length

    rabbitmq_span = spans[0]

    assert_equal :rabbitmq, rabbitmq_span[:n]
    assert_equal 'instana.test.exchange', rabbitmq_span[:data][:rabbitmq][:exchange]
    assert_equal 'test.key', rabbitmq_span[:data][:rabbitmq][:key]

    custom_exchange.delete
  end

  def test_subscribe_with_tracing
    skip unless defined?(::Bunny)
    clear_all!

    # Publish a message first
    ::Instana.tracer.in_span(:rabbitmq_producer) do
      @exchange.publish('test message', routing_key: @queue.name)
    end

    clear_all!

    # Subscribe and process one message
    message_received = false
    @queue.subscribe(manual_ack: false, block: false) do |delivery_info, properties, payload|
      message_received = true
    end

    # Give it a moment to process
    sleep 0.1

    assert message_received
  end
end
