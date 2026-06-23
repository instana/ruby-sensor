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
    assert_equal 'orders', attrs['messaging.destination.name']
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
    assert_equal 'events', attrs['messaging.destination.name']
    assert_equal 'user.signup', attrs['messaging.rabbitmq.destination.routing_key']
    assert_equal 'receive', attrs['messaging.operation.type']
  end

  def test_rabbitmq_minimal_data
    span = create_span(:rabbitmq, {
                         rabbitmq: { exchange: 'logs', sort: 'publish' }
                       })
    converter = Instana::Exporter::Otlp::MessagingConverter.new(span)
    attrs = converter.send(:convert_attributes)

    assert_equal 'rabbitmq', attrs['messaging.system']
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

  private

  def create_span(name, data)
    span = Instana::Span.new(name)
    span[:data] = data
    span.close
    span
  end
end
