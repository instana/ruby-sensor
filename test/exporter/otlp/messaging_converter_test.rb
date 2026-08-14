# (c) Copyright IBM Corp. 2026

require 'test_helper'
require 'instana/exporter/otlp/messaging_converter'

class MessagingConverterTest < Minitest::Test
  def test_rabbitmq_publish_conversion
    span = create_span(:rabbitmq, {
                         rabbitmq: { exchange: 'orders', key: 'order.created', queue: 'order_queue', address: 'rabbitmq.local', sort: 'publish' }
                       })
    converter = Instana::Exporter::Otlp::MessagingConverter.new(span)
    attrs = converter.send(:convert_attributes)

    assert_equal 'rabbitmq', attrs['messaging.system']
    # Composite: exchange:key  (producer side)
    assert_equal 'orders:order.created', attrs['messaging.destination.name']
    assert_equal 'order.created', attrs['messaging.rabbitmq.destination.routing_key']
    assert_equal 'order_queue', attrs['messaging.rabbitmq.queue']
    assert_equal 'rabbitmq.local', attrs['server.address']
    assert_equal 'send', attrs['messaging.operation.type']
  end

  def test_rabbitmq_consume_conversion
    span = create_span(:rabbitmq, {
                         rabbitmq: { exchange: 'events', key: 'user.signup', address: 'localhost', sort: 'consume' }
                       })
    converter = Instana::Exporter::Otlp::MessagingConverter.new(span)
    attrs = converter.send(:convert_attributes)

    assert_equal 'rabbitmq', attrs['messaging.system']
    # Composite: exchange:key  (no queue present)
    assert_equal 'events:user.signup', attrs['messaging.destination.name']
    assert_equal 'user.signup', attrs['messaging.rabbitmq.destination.routing_key']
    assert_equal 'receive', attrs['messaging.operation.type']
  end

  def test_rabbitmq_consume_with_distinct_queue
    span = create_span(:rabbitmq, {
                         rabbitmq: { exchange: 'events', key: 'user.signup', queue: 'signup_queue', address: 'localhost', sort: 'consume' }
                       })
    converter = Instana::Exporter::Otlp::MessagingConverter.new(span)
    attrs = converter.send(:convert_attributes)

    # Composite: exchange:key:queue  (queue differs from key)
    assert_equal 'events:user.signup:signup_queue', attrs['messaging.destination.name']
  end

  def test_rabbitmq_consume_deduplicates_key_equals_queue
    span = create_span(:rabbitmq, {
                         rabbitmq: { exchange: 'events', key: 'signup_queue', queue: 'signup_queue', sort: 'consume' }
                       })
    converter = Instana::Exporter::Otlp::MessagingConverter.new(span)
    attrs = converter.send(:convert_attributes)

    # queue == key so it is omitted
    assert_equal 'events:signup_queue', attrs['messaging.destination.name']
  end

  def test_rabbitmq_minimal_data
    span = create_span(:rabbitmq, {
                         rabbitmq: { exchange: 'logs', sort: 'publish' }
                       })
    converter = Instana::Exporter::Otlp::MessagingConverter.new(span)
    attrs = converter.send(:convert_attributes)

    assert_equal 'rabbitmq', attrs['messaging.system']
    # Only exchange present → no key to append
    assert_equal 'logs', attrs['messaging.destination.name']
    assert_equal 'send', attrs['messaging.operation.type']
    assert_nil attrs['messaging.rabbitmq.destination.routing_key']
    assert_nil attrs['messaging.rabbitmq.queue']
  end

  def test_missing_rabbitmq_data
    span = create_span(:rabbitmq, {})
    converter = Instana::Exporter::Otlp::MessagingConverter.new(span)
    attrs = converter.send(:convert_attributes)

    assert_empty attrs
  end

  # --- span_name tests ---

  def test_span_name_publish_uses_exchange
    span = create_span(:rabbitmq, { rabbitmq: { exchange: 'orders', queue: 'order_queue', sort: 'publish' } })
    result = Instana::Exporter::Otlp::MessagingConverter.new(span).convert
    assert_equal 'orders publish', result[:name]
  end

  def test_span_name_publish_falls_back_to_queue_when_no_exchange
    span = create_span(:rabbitmq, { rabbitmq: { queue: 'order_queue', sort: 'publish' } })
    result = Instana::Exporter::Otlp::MessagingConverter.new(span).convert
    assert_equal 'order_queue publish', result[:name]
  end

  def test_span_name_receive_uses_queue
    span = create_span(:rabbitmq, { rabbitmq: { exchange: 'events', queue: 'events_q', sort: 'consume' } })
    result = Instana::Exporter::Otlp::MessagingConverter.new(span).convert
    assert_equal 'events_q receive', result[:name]
  end

  def test_span_name_falls_back_to_receive_when_no_queue
    span = create_span(:rabbitmq, { rabbitmq: { sort: 'consume' } })
    result = Instana::Exporter::Otlp::MessagingConverter.new(span).convert
    assert_equal 'receive', result[:name]
  end

  private

  def create_span(name, data)
    span = Instana::Span.new(name)
    span[:data] = data
    span.close
    span
  end
end
