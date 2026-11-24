# (c) Copyright IBM Corp. 2026

require 'test_helper'
require 'instana/exporter/otlp/graphql_converter'

class GraphqlConverterTest < Minitest::Test
  def test_graphql_conversion
    span = create_span(:'graphql.server', {
                         graphql: {
                           operationName: 'GetUser',
                           operationType: 'query',
                           document: 'query GetUser { user { id name } }'
                         }
                       })
    converter = Instana::Exporter::Otlp::GraphqlConverter.new(span)
    attrs = converter.send(:convert_attributes)

    assert_equal 'GetUser', attrs['graphql.operation.name']
    assert_equal 'query', attrs['graphql.operation.type']
    assert_equal 'query GetUser { user { id name } }', attrs['graphql.document']
    assert_nil attrs['graphql.arguments']
    assert_nil attrs['error.type']
    assert_equal 'query GetUser', converter.span_name
  end

  def test_graphql_fallback_to_fields_when_no_document
    span = create_span(:'graphql.server', {
                         graphql: {
                           operationName: 'ListTasks',
                           operationType: 'query',
                           fields: { 'tasks' => ['nodes'], 'nodes' => ['action'] }
                         }
                       })
    converter = Instana::Exporter::Otlp::GraphqlConverter.new(span)
    attrs = converter.send(:convert_attributes)

    assert_equal 'tasks { nodes }, nodes { action }', attrs['graphql.document']
  end

  def test_graphql_with_errors
    span = create_span(:'graphql.server', {
                         graphql: {
                           operationName: 'CreatePost',
                           operationType: 'mutation',
                           errors: ['Unauthorized', 'Validation failed']
                         }
                       })
    converter = Instana::Exporter::Otlp::GraphqlConverter.new(span)
    attrs = converter.send(:convert_attributes)

    assert_equal 'Unauthorized, Validation failed', attrs['error.type']
  end

  def test_graphql_span_names
    # Operation type and name
    span = create_span(:'graphql.server', { graphql: { operationType: 'mutation', operationName: 'UpdateUser' } })
    assert_equal 'mutation UpdateUser', Instana::Exporter::Otlp::GraphqlConverter.new(span).span_name

    # Operation type only
    span = create_span(:'graphql.server', { graphql: { operationType: 'subscription' } })
    assert_equal 'subscription', Instana::Exporter::Otlp::GraphqlConverter.new(span).span_name

    # Neither operation type nor name
    span = create_span(:'graphql.server', { graphql: {} })
    assert_equal 'graphql', Instana::Exporter::Otlp::GraphqlConverter.new(span).span_name

    # No data
    span = create_span(:'graphql.server', {})
    assert_equal 'graphql', Instana::Exporter::Otlp::GraphqlConverter.new(span).span_name
  end

  private

  def create_span(name, data)
    span = Instana::Span.new(name)
    span[:data] = data
    span.close
    span
  end
end
