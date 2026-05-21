# (c) Copyright IBM Corp. 2025

require 'test_helper'
require 'instana/exporter/otlp/http_converter'

class HttpConverterTest < Minitest::Test
  def setup
    @base_span_data = {
      t: '1234567890abcdef',
      s: 'abcdef1234567890',
      p: 'fedcba0987654321',
      n: :nethttp,
      k: 2,
      ts: 1_716_234_000_000,
      d: 150
    }
  end

  def test_convert_http_client_span_with_all_attributes
    span = create_http_span(
      method: 'GET',
      url: 'https://api.example.com/users/123',
      status: 200,
      host: 'api.example.com',
      path: '/users/123',
      header: { 'user-agent' => 'Ruby/3.2.0' }
    )

    converter = Instana::Exporter::Otlp::HttpConverter.new(span)
    result = converter.convert

    # Verify base attributes
    assert_equal span.trace_id, result[:trace_id]
    assert_equal span.id, result[:span_id]
    assert_equal span.parent_id, result[:parent_span_id]
    assert_equal :nethttp, result[:name]
    assert_equal 3, result[:kind] # CLIENT kind

    # Verify HTTP attributes are present
    attributes = result[:attributes]
    assert_http_attribute(attributes, 'http.method', 'GET')
    assert_http_attribute(attributes, 'http.url', 'https://api.example.com/users/123')
    assert_http_attribute(attributes, 'http.status_code', 200)
    assert_http_attribute(attributes, 'http.host', 'api.example.com')
    assert_http_attribute(attributes, 'http.target', '/users/123')
    assert_http_attribute(attributes, 'http.scheme', 'https')
    assert_http_attribute(attributes, 'http.user_agent', 'Ruby/3.2.0')
  end

  def test_convert_http_server_span
    span = create_http_span(
      method: 'POST',
      url: 'https://myapp.com/api/orders',
      status: 201,
      host: 'myapp.com',
      path: '/api/orders',
      kind: 1 # Server/entry span
    )

    converter = Instana::Exporter::Otlp::HttpConverter.new(span)
    result = converter.convert

    assert_equal 2, result[:kind] # SERVER kind
    attributes = result[:attributes]
    assert_http_attribute(attributes, 'http.method', 'POST')
    assert_http_attribute(attributes, 'http.status_code', 201)
  end

  def test_convert_http_span_with_minimal_data
    span = create_http_span(method: 'GET')

    converter = Instana::Exporter::Otlp::HttpConverter.new(span)
    result = converter.convert

    # Should still have base attributes
    assert result[:trace_id]
    assert result[:span_id]
    assert result[:attributes]

    # Should have at least the method attribute
    attributes = result[:attributes]
    assert_http_attribute(attributes, 'http.method', 'GET')
  end

  def test_convert_http_span_without_http_data
    span = Instana::Span.new(:nethttp)
    span[:k] = 2
    span.close

    converter = Instana::Exporter::Otlp::HttpConverter.new(span)
    result = converter.convert

    # Should return base attributes with empty HTTP attributes
    assert result[:attributes]
    assert_instance_of Array, result[:attributes]
  end

  def test_extract_scheme_from_https_url
    span = create_http_span(url: 'https://api.example.com/path')
    converter = Instana::Exporter::Otlp::HttpConverter.new(span)
    result = converter.convert

    attributes = result[:attributes]
    assert_http_attribute(attributes, 'http.scheme', 'https')
  end

  def test_extract_scheme_from_http_url
    span = create_http_span(url: 'http://api.example.com/path')
    converter = Instana::Exporter::Otlp::HttpConverter.new(span)
    result = converter.convert

    attributes = result[:attributes]
    assert_http_attribute(attributes, 'http.scheme', 'http')
  end

  def test_extract_scheme_from_invalid_url
    span = create_http_span(url: 'not a valid url')
    converter = Instana::Exporter::Otlp::HttpConverter.new(span)
    result = converter.convert

    attributes = result[:attributes]
    # Should not have scheme attribute for invalid URL
    refute_http_attribute(attributes, 'http.scheme')
  end

  def test_extract_scheme_from_nil_url
    span = create_http_span(url: nil)
    converter = Instana::Exporter::Otlp::HttpConverter.new(span)
    result = converter.convert

    attributes = result[:attributes]
    # Should not have scheme attribute for nil URL
    refute_http_attribute(attributes, 'http.scheme')
  end

  def test_http_attributes_with_nil_values_are_not_included
    span = create_http_span(
      method: 'GET',
      url: nil,
      status: nil,
      host: nil,
      path: nil
    )

    converter = Instana::Exporter::Otlp::HttpConverter.new(span)
    result = converter.convert

    attributes = result[:attributes]
    # Only method should be present
    assert_http_attribute(attributes, 'http.method', 'GET')
    refute_http_attribute(attributes, 'http.url')
    refute_http_attribute(attributes, 'http.status_code')
    refute_http_attribute(attributes, 'http.host')
    refute_http_attribute(attributes, 'http.target')
  end

  def test_http_status_code_as_integer
    span = create_http_span(status: 404)
    converter = Instana::Exporter::Otlp::HttpConverter.new(span)
    result = converter.convert

    attributes = result[:attributes]
    status_attr = attributes.find { |a| a[:key] == 'http.status_code' }
    assert status_attr
    assert_equal 404, status_attr[:value][:int_value]
  end

  def test_http_status_code_as_string
    span = create_http_span(status: '200')
    converter = Instana::Exporter::Otlp::HttpConverter.new(span)
    result = converter.convert

    attributes = result[:attributes]
    status_attr = attributes.find { |a| a[:key] == 'http.status_code' }
    assert status_attr
    # Should be converted to string value since it's a string
    assert status_attr[:value][:string_value] || status_attr[:value][:int_value]
  end

  def test_user_agent_from_header
    span = create_http_span(
      header: {
        'user-agent' => 'Mozilla/5.0',
        'content-type' => 'application/json'
      }
    )

    converter = Instana::Exporter::Otlp::HttpConverter.new(span)
    result = converter.convert

    attributes = result[:attributes]
    assert_http_attribute(attributes, 'http.user_agent', 'Mozilla/5.0')
  end

  def test_user_agent_not_present_when_header_missing
    span = create_http_span(header: { 'content-type' => 'application/json' })
    converter = Instana::Exporter::Otlp::HttpConverter.new(span)
    result = converter.convert

    attributes = result[:attributes]
    refute_http_attribute(attributes, 'http.user_agent')
  end

  def test_user_agent_not_present_when_header_nil
    span = create_http_span(header: nil)
    converter = Instana::Exporter::Otlp::HttpConverter.new(span)
    result = converter.convert

    attributes = result[:attributes]
    refute_http_attribute(attributes, 'http.user_agent')
  end

  def test_convert_with_error_span
    span = create_http_span(
      method: 'GET',
      url: 'https://api.example.com/error',
      status: 500
    )
    span.record_exception(StandardError.new('Server error'))

    converter = Instana::Exporter::Otlp::HttpConverter.new(span)
    result = converter.convert

    # Verify error status
    assert_equal 2, result[:status][:code] # ERROR code

    # Verify HTTP attributes are still present
    attributes = result[:attributes]
    assert_http_attribute(attributes, 'http.method', 'GET')
    assert_http_attribute(attributes, 'http.status_code', 500)
  end

  def test_convert_preserves_base_converter_functionality
    span = create_http_span(method: 'GET', url: 'https://example.com')

    converter = Instana::Exporter::Otlp::HttpConverter.new(span)
    result = converter.convert

    # Verify all base attributes are present
    assert result[:trace_id]
    assert result[:span_id]
    assert result[:name]
    assert result[:kind]
    assert result[:start_time_unix_nano]
    assert result[:end_time_unix_nano]
    assert result[:status]
    assert result[:attributes]
  end

  def test_http_attributes_use_semantic_conventions
    span = create_http_span(
      method: 'GET',
      url: 'https://api.example.com/test',
      status: 200,
      host: 'api.example.com',
      path: '/test'
    )

    converter = Instana::Exporter::Otlp::HttpConverter.new(span)
    result = converter.convert

    attributes = result[:attributes]

    # Verify semantic convention keys are used
    expected_keys = [
      'http.method',
      'http.url',
      'http.status_code',
      'http.host',
      'http.target',
      'http.scheme'
    ]

    expected_keys.each do |key|
      assert attributes.any? { |a| a[:key] == key }, "Expected attribute key '#{key}' not found"
    end
  end

  def test_multiple_http_spans_conversion
    spans = [
      create_http_span(method: 'GET', status: 200),
      create_http_span(method: 'POST', status: 201),
      create_http_span(method: 'DELETE', status: 204)
    ]

    results = spans.map do |span|
      converter = Instana::Exporter::Otlp::HttpConverter.new(span)
      converter.convert
    end

    assert_equal 3, results.length
    assert_http_attribute(results[0][:attributes], 'http.method', 'GET')
    assert_http_attribute(results[1][:attributes], 'http.method', 'POST')
    assert_http_attribute(results[2][:attributes], 'http.method', 'DELETE')
  end

  private

  def create_http_span(http_data = {})
    span = Instana::Span.new(:nethttp)
    span[:n] = :nethttp
    span[:k] = http_data.delete(:kind) || 2 # Default to client
    span[:data] = {
      http: http_data.compact
    }
    span.close
    span
  end

  def assert_http_attribute(attributes, key, expected_value)
    attr = attributes.find { |a| a[:key] == key }
    assert attr, "Expected attribute '#{key}' not found"

    actual_value = attr[:value][:string_value] ||
                   attr[:value][:int_value] ||
                   attr[:value][:double_value] ||
                   attr[:value][:bool_value]

    assert_equal expected_value, actual_value,
                 "Expected attribute '#{key}' to have value '#{expected_value}', got '#{actual_value}'"
  end

  def refute_http_attribute(attributes, key)
    attr = attributes.find { |a| a[:key] == key }
    assert_nil attr, "Expected attribute '#{key}' to not be present, but it was found"
  end
end
