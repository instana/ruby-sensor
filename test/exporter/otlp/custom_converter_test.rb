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

  # --- span_name tests ---

  def test_span_name_uses_sdk_name
    span = Instana::Span.new(:my_custom_span)
    span[:data] = { sdk: { name: 'my-operation', type: 'custom' } }
    span.close
    result = Instana::Exporter::Otlp::CustomConverter.new(span).convert
    assert_equal 'my-operation', result[:name]
  end

  def test_span_name_falls_back_to_span_name_when_no_sdk_name
    # When no sdk[:name] is set, CustomConverter falls back to super
    # (BaseConverter#span_name -> span.name.to_s). For an unregistered
    # span Instana stores the original name in sdk[:name] — so we must
    # not override it. Here we simulate a span where sdk[:name] is nil
    # so span.name returns nil and the result is an empty string.
    span = Instana::Span.new(:my_custom_span)
    # Overwrite sdk[:name] with nil to test the nil-name branch
    span[:data][:sdk][:name] = nil
    span.close
    result = Instana::Exporter::Otlp::CustomConverter.new(span).convert
    assert_equal '', result[:name]
  end
end
