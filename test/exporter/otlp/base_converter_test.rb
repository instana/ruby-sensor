# (c) Copyright IBM Corp. 2025

require 'test_helper'
require 'instana/exporter/otlp/base_converter'

class BaseConverterTest < Minitest::Test
  def setup
    @span = create_test_span
  end

  def test_initialize_with_span
    converter = Instana::Exporter::Otlp::BaseConverter.new(@span)
    assert_instance_of Instana::Exporter::Otlp::BaseConverter, converter
  end

  def test_convert_returns_span_data
    # Use a registered span name so it doesn't become a custom span
    span = create_test_span(name: :rack)
    converter = Instana::Exporter::Otlp::BaseConverter.new(span)
    span_data = converter.convert

    assert_instance_of Instana::Exporter::Otlp::BaseConverter::SpanData, span_data
    assert_equal 'rack', span_data.name
    assert_instance_of String, span_data.trace_id
    assert_instance_of String, span_data.span_id
  end

  def test_convert_span_kind
    # Test explicit internal kind
    span = create_test_span(name: :rack, kind: 3) # Instana intermediate/internal
    converter = TestConverter.new(span)
    assert_equal :internal, converter.send(:convert_span_kind)

    # Test explicit server kind
    span = create_test_span(name: :rack, kind: 1) # Instana entry/server
    converter = TestConverter.new(span)
    assert_equal :server, converter.send(:convert_span_kind)

    # Test explicit client kind
    span = create_test_span(name: :activerecord, kind: 2) # Instana exit/client
    converter = TestConverter.new(span)
    assert_equal :client, converter.send(:convert_span_kind)

    # Test inferred server kind from ENTRY_SPANS (no explicit kind)
    span = create_test_span(name: :rack, kind: nil)
    converter = TestConverter.new(span)
    assert_equal :server, converter.send(:convert_span_kind)

    # Test inferred client kind from EXIT_SPANS (no explicit kind)
    span = create_test_span(name: :activerecord, kind: nil)
    converter = TestConverter.new(span)
    assert_equal :client, converter.send(:convert_span_kind)

    # Test default internal kind for unknown span (no explicit kind)
    span = create_test_span(name: :actionview, kind: nil)
    converter = TestConverter.new(span)
    assert_equal :internal, converter.send(:convert_span_kind)
  end

  def test_convert_to_unix_nano
    converter = TestConverter.new(@span)

    # Test with Time object
    time = Time.now
    result = converter.send(:convert_to_unix_nano, time)
    assert_instance_of Integer, result
    assert result.positive?
    # Verify it's in nanoseconds (should be a very large number)
    assert result > 1_000_000_000_000_000_000

    # Test with integer (milliseconds) - converts to nanoseconds
    timestamp_ms = 1_234_567_890
    result = converter.send(:convert_to_unix_nano, timestamp_ms)
    assert_equal timestamp_ms * 1_000_000, result

    # Test nanosecond precision
    time = Time.at(1_234_567_890, 123_456.789) # seconds, microseconds
    result = converter.send(:convert_to_unix_nano, time)
    expected = (time.to_f * 1_000_000_000).to_i
    assert_equal expected, result
  end

  def test_convert_status
    # Test UNSET status (no error)
    span = create_test_span(name: :rack)
    converter = TestConverter.new(span)
    status = converter.send(:convert_status)
    assert_equal OpenTelemetry::Trace::Status::UNSET, status.code
    assert_equal '', status.description

    # Test ERROR status
    span = create_test_span(name: :rack)
    span.record_exception(StandardError.new('Test error'))
    converter = TestConverter.new(span)
    status = converter.send(:convert_status)
    assert_equal OpenTelemetry::Trace::Status::ERROR, status.code
  end

  def test_convert_attributes
    # Test empty attributes for base converter
    span = create_test_span(data: { undefined: { method: 'GET', url: 'http://example.com' } })
    converter = TestConverter.new(span)
    attributes = converter.send(:convert_attributes)
    assert_instance_of Hash, attributes
    assert attributes.empty?
  end

  def test_normalize_attribute_value
    converter = TestConverter.new(@span)

    # Test string value
    result = converter.send(:normalize_attribute_value, 'test')
    assert_equal 'test', result

    # Test integer value
    result = converter.send(:normalize_attribute_value, 42)
    assert_equal 42, result

    # Test float value
    result = converter.send(:normalize_attribute_value, 3.14)
    assert_equal 3.14, result

    # Test true value
    result = converter.send(:normalize_attribute_value, true)
    assert_equal true, result

    # Test false value
    result = converter.send(:normalize_attribute_value, false)
    assert_equal false, result

    # Test symbol value (should convert to string)
    result = converter.send(:normalize_attribute_value, :test)
    assert_equal 'test', result

    # Test array value
    result = converter.send(:normalize_attribute_value, %w[a b c])
    assert_instance_of Array, result
    assert_equal 3, result.length

    # Test other type (should convert to string)
    result = converter.send(:normalize_attribute_value, { key: 'value' })
    assert_instance_of String, result
  end

  def test_span_accessor
    converter = TestConverter.new(@span)
    assert_equal @span, converter.send(:span)
  end

  def test_convert_with_parent_and_root_spans
    # Test with parent span
    parent_span = create_test_span
    child_span = Instana::Span.new(:test, parent_span)
    child_span.close
    converter = TestConverter.new(child_span)
    span_data = converter.convert
    assert_equal parent_span.trace_id, child_span.trace_id
    refute_equal OpenTelemetry::Trace::INVALID_SPAN_ID, span_data.parent_span_id

    # Test with root span
    root_span = create_test_span
    converter = TestConverter.new(root_span)
    span_data = converter.convert
    assert_equal OpenTelemetry::Trace::INVALID_SPAN_ID, span_data.parent_span_id
  end

  private

  def create_test_span(kind: 3, data: nil, name: :rack)
    span = Instana::Span.new(name)
    span[:k] = kind if kind
    span[:data] = data if data
    span.close
    span
  end

  # Test converter class that exposes protected methods for testing
  class TestConverter < Instana::Exporter::Otlp::BaseConverter
    # Make protected methods public for testing
    public :convert_span_kind, :convert_to_unix_nano,
           :convert_status, :convert_attributes, :normalize_attribute_value, :span
  end
end
