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

  def test_convert_raises_not_implemented_error
    converter = Instana::Exporter::Otlp::BaseConverter.new(@span)
    error = assert_raises(NotImplementedError) do
      converter.convert
    end
    assert_match(/must implement #convert/, error.message)
  end

  def test_extract_common_attributes
    converter = TestConverter.new(@span)
    attributes = converter.send(:extract_common_attributes)

    assert_equal @span.trace_id, attributes[:trace_id]
    assert_equal @span.id, attributes[:span_id]
    assert_nil attributes[:parent_span_id]
    assert_equal @span.name, attributes[:name]
    assert_instance_of Integer, attributes[:start_time_unix_nano]
    assert_instance_of Integer, attributes[:end_time_unix_nano]
    assert_instance_of Hash, attributes[:status]
    assert_instance_of Array, attributes[:attributes]
  end

  def test_convert_span_kind
    # Test internal kind
    span = create_test_span(kind: 3) # Instana intermediate/internal
    converter = TestConverter.new(span)
    assert_equal 1, converter.send(:convert_span_kind) # OTLP INTERNAL

    # Test server kind
    span = create_test_span(kind: 1) # Instana entry/server
    converter = TestConverter.new(span)
    assert_equal 2, converter.send(:convert_span_kind) # OTLP SERVER

    # Test client kind
    span = create_test_span(kind: 2) # Instana exit/client
    converter = TestConverter.new(span)
    assert_equal 3, converter.send(:convert_span_kind) # OTLP CLIENT

    # Test unspecified kind
    span = create_test_span(kind: 99) # Unknown kind
    converter = TestConverter.new(span)
    assert_equal 0, converter.send(:convert_span_kind) # OTLP UNSPECIFIED
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

    # Test with integer
    timestamp = 1_234_567_890
    result = converter.send(:convert_to_unix_nano, timestamp)
    assert_equal timestamp, result

    # Test nanosecond precision
    time = Time.at(1_234_567_890, 123_456.789) # seconds, microseconds
    result = converter.send(:convert_to_unix_nano, time)
    expected = (time.to_f * 1_000_000_000).to_i
    assert_equal expected, result
  end

  def test_convert_status
    # Test OK status
    span = create_test_span
    converter = TestConverter.new(span)
    status = converter.send(:convert_status)
    assert_equal 1, status[:code] # OK
    assert_equal '', status[:message]

    # Test ERROR status
    span = create_test_span
    span.record_exception(StandardError.new('Test error'))
    converter = TestConverter.new(span)
    status = converter.send(:convert_status)
    assert_equal 2, status[:code] # ERROR
  end

  def test_convert_attributes
    # Test empty attributes if the span type has no convertor defined
    span = create_test_span(data: { undefined: { method: 'GET', url: 'http://example.com' } })
    converter = TestConverter.new(span)
    attributes = converter.send(:convert_attributes)
    assert_instance_of Array, attributes
    assert attributes.empty?
  end

  def test_convert_attribute_value
    converter = TestConverter.new(@span)

    # Test string value
    result = converter.send(:convert_attribute_value, 'test')
    assert_equal({ string_value: 'test' }, result)

    # Test integer value
    result = converter.send(:convert_attribute_value, 42)
    assert_equal({ int_value: 42 }, result)

    # Test float value
    result = converter.send(:convert_attribute_value, 3.14)
    assert_equal({ double_value: 3.14 }, result)

    # Test true value
    result = converter.send(:convert_attribute_value, true)
    assert_equal({ bool_value: true }, result)

    # Test false value
    result = converter.send(:convert_attribute_value, false)
    assert_equal({ bool_value: false }, result)

    # Test array value
    result = converter.send(:convert_attribute_value, %w[a b c])
    assert_instance_of Hash, result[:array_value]
    assert_instance_of Array, result[:array_value][:values]
    assert_equal 3, result[:array_value][:values].length

    # Test other type (should convert to string)
    result = converter.send(:convert_attribute_value, { key: 'value' })
    assert result.key?(:string_value)
    assert_instance_of String, result[:string_value]
  end

  def test_has_errors
    # Test returns false for OK span
    span = create_test_span
    converter = TestConverter.new(span)
    refute converter.send(:errors?)

    # Test returns true for error span
    span = create_test_span
    span.record_exception(StandardError.new('Test error'))
    converter = TestConverter.new(span)
    assert converter.send(:errors?)
  end

  def test_span_accessor
    converter = TestConverter.new(@span)
    assert_equal @span, converter.send(:span)
  end

  def test_extract_common_attributes_with_parent_and_root_spans
    # Test with parent span
    parent_span = create_test_span
    child_span = Instana::Span.new(:test, parent_span)
    child_span.close
    converter = TestConverter.new(child_span)
    attributes = converter.send(:extract_common_attributes)
    assert_equal parent_span.id, attributes[:parent_span_id]
    assert_equal parent_span.trace_id, attributes[:trace_id]

    # Test with root span
    root_span = create_test_span
    converter = TestConverter.new(root_span)
    attributes = converter.send(:extract_common_attributes)
    assert_nil attributes[:parent_span_id]
  end

  private

  def create_test_span(kind: 3, data: nil)
    span = Instana::Span.new(:test)
    span[:k] = kind if kind
    span[:data] = data if data
    span.close
    span
  end

  # Test converter class that exposes protected methods for testing
  class TestConverter < Instana::Exporter::Otlp::BaseConverter
    def convert
      extract_common_attributes
    end

    # Make protected methods public for testing
    public :extract_common_attributes, :convert_span_kind, :convert_to_unix_nano,
           :convert_status, :convert_attributes, :convert_attribute_value, :errors?, :span
  end
end
