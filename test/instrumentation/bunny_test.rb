# (c) Copyright IBM Corp. 2025

require 'test_helper'

class BunnyTest < Minitest::Test # rubocop:disable Metrics/ClassLength
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
    @queue.purge
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
    @queue.subscribe(manual_ack: false, block: false) do |_delivery_info, _properties, _payload|
      message_received = true
    end

    # Give it a moment to process
    sleep 0.1

    assert message_received
  end

  def test_consume_with_context_propagation
    skip unless defined?(::Bunny)
    clear_all!

    # First, publish a message with trace context
    trace_id = nil
    span_id = nil

    ::Instana.tracer.in_span(:rabbitmq_producer) do |span|
      trace_id = span.context.trace_id
      span_id = span.context.span_id
      @exchange.publish('test message', routing_key: @queue.name)
    end

    clear_all!

    # Now consume the message
    _, properties, = @queue.pop

    # Simulate consumer processing with context extraction
    return unless properties && properties.headers

    context = {
      trace_id: properties.headers['X-Instana-T'],
      span_id: properties.headers['X-Instana-S'],
      level: properties.headers['X-Instana-L']&.to_i
    }

    # Verify context was propagated
    # The trace_id should match (same trace)
    assert_equal trace_id, context[:trace_id]
    # The span_id in the header is the rabbitmq span's ID (child of rabbitmq_producer)
    # so it won't match the parent's span_id, but we verify it exists
    refute_nil context[:span_id]
    refute_equal span_id, context[:span_id] # Should be different (child span)
    refute_nil context[:level]
  end

  def test_error_handling_in_publish
    skip unless defined?(::Bunny)
    clear_all!

    # Close channel to force an error
    @channel.close

    error_raised = nil
    ::Instana.tracer.in_span(:rabbitmq_test) do
      @exchange.publish('test message', routing_key: @queue.name)
    rescue => e
      error_raised = e
    end

    # Verify error was raised
    refute_nil error_raised

    # Should record both spans (parent and rabbitmq span with error)
    spans = ::Instana.processor.queued_spans
    assert spans.length >= 2

    # Find the rabbitmq span
    rabbitmq_span = spans.find { |s| s[:n] == :rabbitmq }
    refute_nil rabbitmq_span, "RabbitMQ span should be present"

    # Verify error is recorded in the span
    assert_equal true, rabbitmq_span[:error], "Span should have error flag set"
    assert_equal 1, rabbitmq_span[:ec], "Error count should be 1"

    # Verify error message is logged in span data
    assert rabbitmq_span[:data][:log], "Span should have log data"
    log_entry = rabbitmq_span[:data][:log]
    assert log_entry[:message], "Log should have a message"
    assert_equal error_raised.message, log_entry[:message], "Log message should contain the actual error message"
    assert_equal error_raised.class.to_s, log_entry[:parameters], "Log parameters should contain error class"
  end

  def test_exception_handling_in_publish_without_tracing
    skip unless defined?(::Bunny)
    clear_all!

    # Verify that exceptions are properly raised even when not tracing
    @channel.close

    exception_raised = false
    begin
      @exchange.publish('test message', routing_key: @queue.name)
    rescue Bunny::ChannelAlreadyClosed, Bunny::ConnectionClosedError => e
      exception_raised = true
      assert e.message.length.positive?, "Exception should have a message"
    end

    assert exception_raised, "Exception should be raised when publishing to closed channel"
  end

  def test_exception_handling_in_pop_without_tracing
    skip unless defined?(::Bunny)
    clear_all!

    # Publish a message first
    @exchange.publish('test message', routing_key: @queue.name)

    # Close channel before consuming
    @channel.close

    exception_raised = false
    begin
      @queue.pop
    rescue Bunny::ChannelAlreadyClosed, Bunny::ConnectionClosedError => e
      exception_raised = true
      assert e.message.length.positive?, "Exception should have a message"
    end

    assert exception_raised, "Exception should be raised when consuming from closed channel"
  end

  def test_exception_in_subscribe_block
    skip unless defined?(::Bunny)
    clear_all!

    # Verify exceptions in subscribe blocks are handled properly
    @exchange.publish('test message', routing_key: @queue.name)

    exception_caught = false
    error_message = nil

    @queue.subscribe(manual_ack: false, block: false) do |_delivery_info, _properties, _payload|
      raise StandardError, "Test exception in consumer"
    rescue => e
      exception_caught = true
      error_message = e.message
    end

    sleep 0.2

    assert exception_caught, "Exception should be caught in subscribe block"
    assert_equal "Test exception in consumer", error_message
  end

  def test_pop_with_tracing
    skip unless defined?(::Bunny)
    clear_all!

    # Publish a message first
    @exchange.publish('test message for pop', routing_key: @queue.name)

    # Pop the message with active tracing
    ::Instana.tracer.in_span(:rabbitmq_consumer_test) do
      delivery_info, _, payload = @queue.pop

      refute_nil delivery_info
      assert_equal 'test message for pop', payload
    end

    spans = ::Instana.processor.queued_spans
    assert_equal 2, spans.length

    rabbitmq_span = spans[0]
    consumer_span = spans[1]

    # Verify parent-child relationship
    assert_equal consumer_span[:s], rabbitmq_span[:p]

    # Verify RabbitMQ consume span details
    assert_equal :rabbitmq, rabbitmq_span[:n]
    assert_equal 'consume', rabbitmq_span[:data][:rabbitmq][:sort]
    assert_equal @queue.name, rabbitmq_span[:data][:rabbitmq][:queue]
    assert_equal 'default', rabbitmq_span[:data][:rabbitmq][:exchange]
    assert rabbitmq_span[:data][:rabbitmq][:address]
  end

  def test_pop_with_trace_context_extraction
    skip unless defined?(::Bunny)
    clear_all!

    # Publish a message with trace context
    original_trace_id = nil
    original_span_id = nil

    @queue.purge
    ::Instana.tracer.in_span(:rabbitmq_producer) do |span|
      original_trace_id = span.context.trace_id
      original_span_id = span.context.span_id
      @exchange.publish('test message with context', routing_key: @queue.name)
    end

    clear_all!

    # Pop the message - should extract and continue the trace
    delivery_info, _, payload = @queue.pop

    refute_nil delivery_info
    assert_equal 'test message with context', payload

    spans = ::Instana.processor.queued_spans
    assert_equal 1, spans.length

    rabbitmq_span = spans[0]

    # Verify the span continues the original trace
    assert_equal :rabbitmq, rabbitmq_span[:n]
    assert_equal 'consume', rabbitmq_span[:data][:rabbitmq][:sort]
    assert_equal original_trace_id, rabbitmq_span[:t]
  end

  def test_pop_empty_queue
    skip unless defined?(::Bunny)
    clear_all!

    # Purge the queue to ensure it's empty
    @queue.purge

    # Pop from empty queue - returns nil for all values
    delivery_info, properties, payload = @queue.pop

    assert_nil delivery_info
    assert_nil properties
    assert_nil payload

    # No spans should be created for empty pop (delivery_info is nil, returns early)
    spans = ::Instana.processor.queued_spans
    assert_equal 0, spans.length
  end

  def test_subscribe_with_trace_context_extraction
    skip unless defined?(::Bunny)
    clear_all!

    # Publish a message with trace context
    original_trace_id = nil
    ::Instana.tracer.in_span(:rabbitmq_producer) do |span|
      original_trace_id = span.context.trace_id
      @exchange.publish('test subscribe context', routing_key: @queue.name)
    end

    clear_all!

    # Subscribe and process the message
    message_received = false
    received_payload = nil

    @queue.subscribe(manual_ack: false, block: false) do |_delivery_info, _properties, payload|
      message_received = true
      received_payload = payload
    end

    # Give it time to process
    sleep 0.2

    assert message_received
    assert_equal 'test subscribe context', received_payload

    spans = ::Instana.processor.queued_spans
    assert spans.length >= 1

    rabbitmq_span = spans.find { |s| s[:n] == :rabbitmq }
    refute_nil rabbitmq_span
    assert_equal 'consume', rabbitmq_span[:data][:rabbitmq][:sort]
    assert_equal original_trace_id, rabbitmq_span[:t]
  end

  def test_subscribe_without_block
    skip unless defined?(::Bunny)
    clear_all!

    # Publish a message
    @exchange.publish('test no block', routing_key: @queue.name)

    # Subscribe without a block should return a consumer
    consumer = @queue.subscribe(manual_ack: false, block: false)

    refute_nil consumer
    assert consumer.is_a?(Bunny::Consumer)

    # Clean up
    consumer.cancel if consumer
  end

  def test_error_handling_in_pop
    skip unless defined?(::Bunny)
    clear_all!

    # Publish a message
    @exchange.publish('test error pop', routing_key: @queue.name)

    # Close the channel to force an error during pop
    @channel.close

    error_raised = false
    begin
      @queue.pop
    rescue
      error_raised = true
    end

    assert error_raised, "Exception should be raised when channel is closed"
  end

  def test_error_handling_in_subscribe
    skip unless defined?(::Bunny)
    clear_all!

    # Publish a message
    @exchange.publish('test error subscribe', routing_key: @queue.name)

    # Subscribe with a block that raises an error
    error_in_block = false

    @queue.subscribe(manual_ack: false, block: false) do |_delivery_info, _properties, _payload|
      error_in_block = true
      raise StandardError, "Intentional error in subscribe block"
    end

    # Give it time to process and error
    sleep 0.2

    assert error_in_block, "Block should have been called and raised error"
  end

  def test_publish_with_empty_exchange_name
    skip unless defined?(::Bunny)
    clear_all!

    # Default exchange has empty name
    ::Instana.tracer.in_span(:rabbitmq_test) do
      @exchange.publish('test empty exchange', routing_key: @queue.name)
    end

    spans = ::Instana.processor.queued_spans
    assert_equal 2, spans.length

    rabbitmq_span = spans[0]
    assert_equal 'default', rabbitmq_span[:data][:rabbitmq][:exchange]
  end

  def test_publish_with_nil_routing_key
    skip unless defined?(::Bunny)
    clear_all!

    ::Instana.tracer.in_span(:rabbitmq_test) do
      @exchange.publish('test nil routing key')
    end

    spans = ::Instana.processor.queued_spans
    assert_equal 2, spans.length

    rabbitmq_span = spans[0]
    assert_equal '', rabbitmq_span[:data][:rabbitmq][:key]
  end

  def test_multiple_messages_consume
    skip unless defined?(::Bunny)
    clear_all!

    # Publish multiple messages
    3.times do |i|
      @exchange.publish("consume message #{i}", routing_key: @queue.name)
    end

    clear_all!

    # Pop all messages with tracing
    messages = []
    ::Instana.tracer.in_span(:rabbitmq_consumer_batch) do
      3.times do
        _, _, payload = @queue.pop
        messages << payload if payload
      end
    end

    assert_equal 3, messages.length

    spans = ::Instana.processor.queued_spans
    # Should have 1 parent span + 3 rabbitmq consume spans
    assert_equal 4, spans.length

    rabbitmq_spans = spans.select { |s| s[:n] == :rabbitmq }
    assert_equal 3, rabbitmq_spans.length

    rabbitmq_spans.each do |span|
      assert_equal 'consume', span[:data][:rabbitmq][:sort]
    end
  end

  def test_publish_with_additional_headers
    skip unless defined?(::Bunny)
    clear_all!

    ::Instana.tracer.in_span(:rabbitmq_test) do
      @exchange.publish('test with headers',
                        routing_key: @queue.name,
                        headers: { 'custom-header' => 'custom-value' })
    end

    # Retrieve the message
    _, properties, = @queue.pop

    refute_nil properties
    refute_nil properties.headers

    # Verify both custom and trace headers are present
    assert_equal 'custom-value', properties.headers['custom-header']
    assert properties.headers['X-Instana-T']
    assert properties.headers['X-Instana-S']
    assert properties.headers['X-Instana-L']
  end

  def test_consume_with_custom_exchange
    skip unless defined?(::Bunny)
    clear_all!

    custom_exchange = @channel.topic('instana.test.consume.exchange', auto_delete: true)
    @queue.bind(custom_exchange, routing_key: 'consume.key')

    # Publish to custom exchange
    custom_exchange.publish('test consume custom', routing_key: 'consume.key')

    # Pop with tracing
    ::Instana.tracer.in_span(:rabbitmq_consumer_test) do
      _, _, payload = @queue.pop
      assert_equal 'test consume custom', payload
    end

    spans = ::Instana.processor.queued_spans
    assert_equal 2, spans.length

    rabbitmq_span = spans[0]
    assert_equal 'instana.test.consume.exchange', rabbitmq_span[:data][:rabbitmq][:exchange]
    assert_equal 'consume.key', rabbitmq_span[:data][:rabbitmq][:key]

    custom_exchange.delete
  end

  def test_publish_error_with_span_error_recording
    skip unless defined?(::Bunny)
    clear_all!

    # Create a scenario where publish will fail
    @channel.close

    ::Instana.tracer.in_span(:rabbitmq_test) do
      @exchange.publish('test message', routing_key: @queue.name)
    rescue
      # Expected to raise
    end

    spans = ::Instana.processor.queued_spans
    rabbitmq_span = spans.find { |s| s[:n] == :rabbitmq }

    # Verify error was properly recorded
    refute_nil rabbitmq_span
    assert_equal true, rabbitmq_span[:error]
    assert_equal 1, rabbitmq_span[:ec]
  end

  def test_subscribe_with_manual_ack
    skip unless defined?(::Bunny)
    clear_all!

    # Publish a message with trace context
    ::Instana.tracer.in_span(:rabbitmq_producer) do
      @exchange.publish('test manual ack', routing_key: @queue.name)
    end

    clear_all!

    # Subscribe with manual acknowledgment
    message_received = false
    @queue.subscribe(manual_ack: true, block: false) do |delivery_info, _properties, payload|
      message_received = true
      assert_equal 'test manual ack', payload
      @channel.ack(delivery_info.delivery_tag)
    end

    sleep 0.2

    assert message_received

    spans = ::Instana.processor.queued_spans
    rabbitmq_span = spans.find { |s| s[:n] == :rabbitmq }
    refute_nil rabbitmq_span
    assert_equal 'consume', rabbitmq_span[:data][:rabbitmq][:sort]
  end

  def test_pop_extracts_all_context_fields
    skip unless defined?(::Bunny)
    clear_all!

    # Publish with full trace context
    ::Instana.tracer.in_span(:rabbitmq_producer) do |_span|
      @exchange.publish('test full context', routing_key: @queue.name)
    end

    clear_all!

    # Pop and verify all context fields are extracted
    _, properties, = @queue.pop

    refute_nil properties.headers['X-Instana-T']
    refute_nil properties.headers['X-Instana-S']
    refute_nil properties.headers['X-Instana-L']

    # Verify the consume span was created with extracted context
    spans = ::Instana.processor.queued_spans
    assert_equal 1, spans.length

    rabbitmq_span = spans[0]
    assert_equal :rabbitmq, rabbitmq_span[:n]
    assert_equal 'consume', rabbitmq_span[:data][:rabbitmq][:sort]
  end

  def test_consume_with_empty_routing_key
    skip unless defined?(::Bunny)
    clear_all!

    # Publish with empty routing key
    @exchange.publish('test empty key', routing_key: '')

    ::Instana.tracer.in_span(:rabbitmq_consumer_test) do
      delivery_info, = @queue.pop

      # Message won't be delivered to queue with empty routing key to default exchange
      # but we test the instrumentation handles it
      if delivery_info
        assert_equal '', delivery_info.routing_key
      end
    end
  end

  def test_multiple_exchanges_and_queues
    skip unless defined?(::Bunny)
    clear_all!

    # Create multiple exchanges and queues
    exchange1 = @channel.topic('instana.test.exchange1', auto_delete: true)
    exchange2 = @channel.topic('instana.test.exchange2', auto_delete: true)
    queue1 = @channel.queue('instana.test.queue1', auto_delete: true)
    queue2 = @channel.queue('instana.test.queue2', auto_delete: true)

    queue1.bind(exchange1, routing_key: 'key1')
    queue2.bind(exchange2, routing_key: 'key2')

    ::Instana.tracer.in_span(:rabbitmq_multi_test) do
      exchange1.publish('message1', routing_key: 'key1')
      exchange2.publish('message2', routing_key: 'key2')
    end

    spans = ::Instana.processor.queued_spans
    # 1 parent + 2 publish spans
    assert_equal 3, spans.length

    rabbitmq_spans = spans.select { |s| s[:n] == :rabbitmq }
    assert_equal 2, rabbitmq_spans.length

    # Verify each span has correct exchange
    exchanges = rabbitmq_spans.map { |s| s[:data][:rabbitmq][:exchange] }.sort
    assert_equal ['instana.test.exchange1', 'instana.test.exchange2'], exchanges

    # Cleanup
    queue1.delete
    queue2.delete
    exchange1.delete
    exchange2.delete
  end

  def test_pop_without_active_trace_but_with_headers
    skip unless defined?(::Bunny)
    clear_all!

    # Publish with trace context
    ::Instana.tracer.in_span(:rabbitmq_producer) do
      @exchange.publish('test no active trace', routing_key: @queue.name)
    end

    clear_all!

    # Pop without active trace - should still create span from headers
    delivery_info, _, payload = @queue.pop

    refute_nil delivery_info
    assert_equal 'test no active trace', payload

    # Should have created a consume span from extracted headers
    spans = ::Instana.processor.queued_spans
    assert_equal 1, spans.length

    rabbitmq_span = spans[0]
    assert_equal :rabbitmq, rabbitmq_span[:n]
    assert_equal 'consume', rabbitmq_span[:data][:rabbitmq][:sort]
  end

  def test_address_field_in_spans
    skip unless defined?(::Bunny)
    clear_all!

    ::Instana.tracer.in_span(:rabbitmq_test) do
      @exchange.publish('test address', routing_key: @queue.name)
    end

    spans = ::Instana.processor.queued_spans
    rabbitmq_span = spans.find { |s| s[:n] == :rabbitmq }

    refute_nil rabbitmq_span
    refute_nil rabbitmq_span[:data][:rabbitmq][:address]
    # Address should be the RabbitMQ host
    assert rabbitmq_span[:data][:rabbitmq][:address].is_a?(String)
  end

  def test_subscribe_error_handling_with_closed_channel
    skip unless defined?(::Bunny)
    clear_all!

    # Publish a message first
    @exchange.publish('test subscribe error', routing_key: @queue.name)

    # Close the channel to force an error during subscribe
    @channel.close

    error_raised = false
    begin
      # This should trigger the rescue block in subscribe method (lines 65-68)
      @queue.subscribe(manual_ack: false, block: false) do |_delivery_info, _properties, _payload|
        # Block should not be reached
      end
    rescue Bunny::ChannelAlreadyClosed, Bunny::ConnectionClosedError => e
      error_raised = true
      # Verify the error has a message (log_error should be called)
      assert e.message.length.positive?
    end

    assert error_raised, "Exception should be raised and logged when subscribing to closed channel"
  end

  def test_pop_error_handling_with_logging
    skip unless defined?(::Bunny)
    clear_all!

    # Publish a message
    @exchange.publish('test pop error', routing_key: @queue.name)

    # Close channel to trigger error in pop (lines 48-51)
    @channel.close

    error_raised = false
    begin
      @queue.pop
    rescue Bunny::ChannelAlreadyClosed, Bunny::ConnectionClosedError => e
      error_raised = true
      # The log_error method (line 124-126) should be called internally
      assert e.message.length.positive?
    end

    assert error_raised, "Exception should be raised and logged in pop"
  end
end
