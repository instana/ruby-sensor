# (c) Copyright IBM Corp. 2026

require 'test_helper'
require 'instana/exporter/otlp/rpc_converter'

class RpcConverterTest < Minitest::Test
  def test_grpc_conversion
    span = create_span(:grpc, {
                         rpc: { call: '/package.Service/Method', host: 'grpc.example.com', call_type: 'unary' }
                       })
    converter = Instana::Exporter::Otlp::RpcConverter.new(span)
    attrs = converter.send(:convert_attributes)

    assert_equal 'grpc', attrs['rpc.system']
    assert_equal 'package.Service', attrs['rpc.service']
    assert_equal 'Method', attrs['rpc.method']
    assert_equal 'grpc.example.com', attrs['server.address']
    assert_equal 'unary', attrs['rpc.grpc.call_type']
  end

  def test_grpc_with_peer_address
    span = create_span(:grpc, {
                         rpc: { call: '/test.API/Get', peer: { address: '10.0.0.1' } }
                       })
    converter = Instana::Exporter::Otlp::RpcConverter.new(span)
    attrs = converter.send(:convert_attributes)

    assert_equal '10.0.0.1', attrs['server.address']
  end

  def test_actioncable_conversion
    span = create_span(:actioncable, {
                         rpc: { flavor: :actioncable, call: 'ChatChannel#speak', host: 'ws.example.com', call_type: 'action' },
                         service: 'my-app'
                       })
    converter = Instana::Exporter::Otlp::RpcConverter.new(span)
    attrs = converter.send(:convert_attributes)

    assert_equal 'actioncable', attrs['rpc.system']
    assert_equal 'ChatChannel#speak', attrs['rails.actioncable.channel']
    assert_equal 'action', attrs['rails.actioncable.call_type']
    assert_equal 'my-app', attrs['rpc.service']
    assert_equal 'ChatChannel', attrs['code.namespace']
    assert_equal 'speak', attrs['code.function']
    assert_equal 'ws.example.com', attrs['server.address']
  end

  def test_actioncable_transmit
    span = create_span(:actioncable, {
                         rpc: { flavor: :actioncable, call: 'NotificationChannel', call_type: 'transmit' }
                       })
    converter = Instana::Exporter::Otlp::RpcConverter.new(span)
    attrs = converter.send(:convert_attributes)

    assert_equal 'NotificationChannel', attrs['code.namespace']
    assert_nil attrs['code.function']
  end

  def test_parse_grpc_call
    span = create_span(:grpc, {})
    converter = Instana::Exporter::Otlp::RpcConverter.new(span)

    service, method = converter.send(:parse_grpc_call, '/pkg.Service/Method')
    assert_equal 'pkg.Service', service
    assert_equal 'Method', method

    service, method = converter.send(:parse_grpc_call, 'invalid')
    assert_nil service
    assert_nil method
  end

  def test_missing_rpc_data
    span = create_span(:grpc, {})
    converter = Instana::Exporter::Otlp::RpcConverter.new(span)
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
