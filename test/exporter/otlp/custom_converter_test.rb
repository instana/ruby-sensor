# (c) Copyright IBM Corp. 2026

require 'test_helper'
require 'instana/exporter/otlp/custom_converter'

class CustomConverterTest < Minitest::Test
  def test_converts_instana_sdk_custom_span_attributes
    span = Instana::Span.new(:my_custom_span)
    span[:data] = { sdk: { name: 'my_custom_span', type: 'custom' } }
    span.close

    attributes = Instana::Exporter::Otlp::CustomConverter.new(span).convert.attributes

    assert_equal 'custom', attributes['instana.span.type']
    assert_equal 'my_custom_span', attributes['instana.sdk.name']
    assert_equal 'custom', attributes['instana.sdk.type']
  end

  def test_converts_custom_tags
    span = Instana::Span.new(:my_custom_span)
    span.set_tag('user.id', 123)
    span.set_tag('request.path', '/api/users')
    span.close

    attributes = Instana::Exporter::Otlp::CustomConverter.new(span).convert.attributes

    assert_equal 123, attributes['user.id']
    assert_equal '/api/users', attributes['request.path']
  end

  def test_converts_custom_tags_from_data_hash
    span = Instana::Span.new(:my_custom_span)
    span[:data] = {
      sdk: {
        custom: {
          tags: { 'param1' => 'value1', 'param2' => 42 }
        }
      }
    }
    span.close

    attributes = Instana::Exporter::Otlp::CustomConverter.new(span).convert.attributes

    assert_equal 'value1', attributes['param1']
    assert_equal 42, attributes['param2']
  end
end
