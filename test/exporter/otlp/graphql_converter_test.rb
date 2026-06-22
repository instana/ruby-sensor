# (c) Copyright IBM Corp. 2026

require 'test_helper'
require 'instana/exporter/otlp/graphql_converter'

class GraphqlConverterTest < Minitest::Test
  def test_convert_attributes_with_full_data
    span = create_span({
                         operationName: 'GetUser',
                         operationType: 'query',
                         fields: { User: %w[id name email], Profile: %w[bio avatar] },
                         arguments: { User: %w[id:123], Profile: %w[userId:123] }
                       })
    converter = Instana::Exporter::Otlp::GraphqlConverter.new(span)
    attrs = converter.send(:convert_attributes)

    assert_equal 'GetUser', attrs['graphql.operation.name']
    assert_equal 'query', attrs['graphql.operation.type']
    assert_equal 'User { id, name, email }, Profile { bio, avatar }', attrs['graphql.document']
    assert_equal 'User(id:123), Profile(userId:123)', attrs['graphql.arguments']
  end

  def test_convert_attributes_without_arguments
    span = create_span({
                         operationName: 'ListPosts',
                         operationType: 'query',
                         fields: { Post: %w[title content] }
                       })
    converter = Instana::Exporter::Otlp::GraphqlConverter.new(span)
    attrs = converter.send(:convert_attributes)

    assert_equal 'ListPosts', attrs['graphql.operation.name']
    assert_equal 'query', attrs['graphql.operation.type']
    assert_equal 'Post { title, content }', attrs['graphql.document']
    refute attrs.key?('graphql.arguments')
  end

  def test_convert_attributes_mutation
    span = create_span({
                         operationName: 'CreateUser',
                         operationType: 'mutation',
                         fields: { User: %w[id name] },
                         arguments: { User: ['name:"John"', 'email:"john@example.com"'] }
                       })
    converter = Instana::Exporter::Otlp::GraphqlConverter.new(span)
    attrs = converter.send(:convert_attributes)

    assert_equal 'CreateUser', attrs['graphql.operation.name']
    assert_equal 'mutation', attrs['graphql.operation.type']
    assert_equal 'User(name:"John", email:"john@example.com")', attrs['graphql.arguments']
  end

  def test_convert_attributes_no_data
    span = Instana::Span.new(:graphql)
    span.close
    converter = Instana::Exporter::Otlp::GraphqlConverter.new(span)
    attrs = converter.send(:convert_attributes)

    assert_empty attrs
  end

  def test_format_fields
    span = create_span({})
    converter = Instana::Exporter::Otlp::GraphqlConverter.new(span)

    result = converter.send(:format_fields, { User: %w[id name], Post: %w[title] })
    assert_equal 'User { id, name }, Post { title }', result

    assert_nil converter.send(:format_fields, nil)
  end

  def test_format_arguments
    span = create_span({})
    converter = Instana::Exporter::Otlp::GraphqlConverter.new(span)

    result = converter.send(:format_arguments, { User: %w[id:1], Post: %w[limit:10] })
    assert_equal 'User(id:1), Post(limit:10)', result

    assert_nil converter.send(:format_arguments, nil)
  end

  private

  def create_span(graphql_data)
    span = Instana::Span.new(:graphql)
    span[:data] = { graphql: graphql_data } unless graphql_data.empty?
    span.close
    span
  end
end
