# (c) Copyright IBM Corp. 2025

require 'test_helper'
require 'instana/exporter/otlp/converter_factory'

class ConverterFactoryTest < Minitest::Test
  def setup
    @factory = Instana::Exporter::Otlp::ConverterFactory
  end

  # ============================================================================
  # HTTP SPAN TYPE TESTS
  # ============================================================================

  def test_returns_http_converter_for_http_spans
    http_span_names = %w[net-http rack excon]

    http_span_names.each do |name|
      span = create_test_span(name: name)
      converter = @factory.create(span)

      assert_equal 'Instana::Exporter::Otlp::HttpConverter', converter.class.name,
                   "Should return HttpConverter for '#{name}' span"
    end
  end

  def test_determine_span_type_returns_http
    span = create_test_span(name: :rack)
    span_type = @factory.send(:determine_span_type, span)

    assert_equal 'http', span_type
  end

  # ============================================================================
  # DATABASE SPAN TYPE TESTS
  # ============================================================================

  def test_returns_database_converter_for_database_spans
    database_span_names = %w[
      sql SQL database query activerecord
      sequel mongo redis dalli
    ]

    database_span_names.each do |name|
      span = create_test_span(name: name)
      converter = @factory.create(span)

      assert_equal 'Instana::Exporter::Otlp::DatabaseConverter', converter.class.name,
                   "Should return DatabaseConverter for '#{name}' span"
    end
  end

  def test_determine_span_type_returns_database
    span = create_test_span(name: 'sql')
    span_type = @factory.send(:determine_span_type, span)

    assert_equal 'database', span_type
  end

  # ============================================================================
  # MESSAGING SPAN TYPE TESTS
  # ============================================================================

  def test_returns_messaging_converter_for_messaging_spans
    messaging_span_names = %w[
      kafka rabbitmq sqs sns message
      bunny shoryuken KAFKA RabbitMQ
    ]

    messaging_span_names.each do |name|
      span = create_test_span(name: name)
      converter = @factory.create(span)

      assert_equal 'Instana::Exporter::Otlp::MessagingConverter', converter.class.name,
                   "Should return MessagingConverter for '#{name}' span"
    end
  end

  def test_determine_span_type_returns_messaging
    span = create_test_span(name: 'kafka')
    span_type = @factory.send(:determine_span_type, span)

    assert_equal 'messaging', span_type
  end

  # ============================================================================
  # RPC SPAN TYPE TESTS
  # ============================================================================

  def test_returns_rpc_converter_for_rpc_spans
    rpc_span_names = %w[grpc GRPC rpc RPC grpc_client grpc_server]

    rpc_span_names.each do |name|
      span = create_test_span(name: name)
      converter = @factory.create(span)

      assert_equal 'Instana::Exporter::Otlp::RpcConverter', converter.class.name,
                   "Should return RpcConverter for '#{name}' span"
    end
  end

  def test_determine_span_type_returns_rpc
    span = create_test_span(name: 'grpc')
    span_type = @factory.send(:determine_span_type, span)

    assert_equal 'rpc', span_type
  end

  # ============================================================================
  # CUSTOM SPAN TYPE TESTS
  # ============================================================================

  def test_returns_custom_converter_for_custom_spans
    custom_span_names = %w[custom CUSTOM sdk SDK custom_span]

    custom_span_names.each do |name|
      span = create_test_span(name: name)
      converter = @factory.create(span)

      assert_equal 'Instana::Exporter::Otlp::CustomConverter', converter.class.name,
                   "Should return CustomConverter for '#{name}' span"
    end
  end

  def test_determine_span_type_returns_custom
    span = create_test_span(name: 'custom')
    span_type = @factory.send(:determine_span_type, span)

    assert_equal 'custom', span_type
  end

  # ============================================================================
  # INTERNAL SPAN TYPE TESTS
  # ============================================================================

  def test_returns_internal_converter_for_internal_spans
    internal_span_names = %w[internal unknown other test]

    internal_span_names.each do |name|
      span = create_test_span(name: name)
      converter = @factory.create(span)

      assert_equal 'Instana::Exporter::Otlp::InternalConverter', converter.class.name,
                   "Should return InternalConverter for '#{name}' span"
    end
  end

  def test_determine_span_type_returns_internal_as_default
    span = create_test_span(name: 'unknown_span_type')
    span_type = @factory.send(:determine_span_type, span)

    assert_equal 'internal', span_type
  end

  # ============================================================================
  # SPAN TYPE PRIORITY TESTS
  # ============================================================================

  def test_database_detection_has_priority_over_messaging
    span = create_test_span(name: 'database_message')
    span_type = @factory.send(:determine_span_type, span)

    assert_equal 'database', span_type,
                 'Database detection should have priority over messaging'
  end

  def test_messaging_detection_has_priority_over_rpc
    span = create_test_span(name: 'kafka_rpc')
    span_type = @factory.send(:determine_span_type, span)

    assert_equal 'messaging', span_type,
                 'Messaging detection should have priority over RPC'
  end

  def test_rpc_detection_has_priority_over_custom
    span = create_test_span(name: 'grpc_custom')
    span_type = @factory.send(:determine_span_type, span)

    assert_equal 'rpc', span_type,
                 'RPC detection should have priority over custom'
  end

  # ============================================================================
  # CONVERTER CLASS RETRIEVAL TESTS
  # ============================================================================

  def test_get_converter_class_for_all_types
    expected_converters = {
      'http' => 'Instana::Exporter::Otlp::HttpConverter',
      'database' => 'Instana::Exporter::Otlp::DatabaseConverter',
      'messaging' => 'Instana::Exporter::Otlp::MessagingConverter',
      'rpc' => 'Instana::Exporter::Otlp::RpcConverter',
      'custom' => 'Instana::Exporter::Otlp::CustomConverter',
      'internal' => 'Instana::Exporter::Otlp::InternalConverter'
    }

    expected_converters.each do |span_type, expected_class_name|
      converter_class = @factory.send(:get_converter_class, span_type)

      assert_equal expected_class_name, converter_class.name,
                   "Should return #{expected_class_name} for '#{span_type}' type"
    end
  end

  # ============================================================================
  # SPAN DETECTION METHOD TESTS
  # ============================================================================

  def test_http_span_detection
    assert @factory.send(:http_span?, create_test_span(name: :rack))
    refute @factory.send(:http_span?, create_test_span(name: :database))
  end

  def test_database_span_detection
    assert @factory.send(:database_span?, create_test_span(name: 'sql'))
    refute @factory.send(:database_span?, create_test_span(name: :http))
  end

  def test_messaging_span_detection
    assert @factory.send(:messaging_span?, create_test_span(name: 'kafka'))
    refute @factory.send(:messaging_span?, create_test_span(name: :http))
  end

  def test_rpc_span_detection
    assert @factory.send(:rpc_span?, create_test_span(name: 'grpc'))
    refute @factory.send(:rpc_span?, create_test_span(name: :http))
  end

  def test_custom_span_detection
    assert @factory.send(:custom_span?, create_test_span(name: 'custom'))
    refute @factory.send(:custom_span?, create_test_span(name: :http))
  end

  # ============================================================================
  # EDGE CASES AND ERROR HANDLING
  # ============================================================================

  def test_handles_nil_span_name
    span = create_test_span(name: nil)
    converter = @factory.create(span)

    assert_equal 'Instana::Exporter::Otlp::InternalConverter', converter.class.name
  end

  def test_handles_empty_span_name
    span = create_test_span(name: '')
    converter = @factory.create(span)

    assert_equal 'Instana::Exporter::Otlp::InternalConverter', converter.class.name
  end

  def test_case_insensitive_detection
    test_cases = {
      'rack' => 'Instana::Exporter::Otlp::HttpConverter',
      'SQL' => 'Instana::Exporter::Otlp::DatabaseConverter',
      'KAFKA' => 'Instana::Exporter::Otlp::MessagingConverter',
      'GRPC' => 'Instana::Exporter::Otlp::RpcConverter',
      'CUSTOM' => 'Instana::Exporter::Otlp::CustomConverter'
    }

    test_cases.each do |name, expected_class|
      span = create_test_span(name: name)
      converter = @factory.create(span)

      assert_equal expected_class, converter.class.name,
                   "Should handle case-insensitive detection for '#{name}'"
    end
  end

  def test_converter_has_reference_to_span
    span = create_test_span(name: :nethttp)
    converter = @factory.create(span)

    assert_equal span, converter.send(:span),
                 'Converter should have reference to original span'
  end

  private

  def create_test_span(name: :test, kind: 3)
    span = Instana::Span.new(name)
    span[:k] = kind
    span.close
    span
  end
end
