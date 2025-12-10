# (c) Copyright IBM Corp. 2025

require 'test_helper'

class ConditionTest < Minitest::Test
  def setup
    @http_span = {
      n: 'http.client',
      k: 1,
      data: {
        http: {
          url: 'https://example.com/api',
          method: 'GET',
          status: 200
        }
      }
    }

    @redis_span = {
      n: 'redis',
      k: 3,
      data: {
        redis: {
          command: 'GET',
          key: 'user:123'
        }
      }
    }
  end

  def test_initialization
    condition = Instana::SpanFiltering::Condition.new('type', ['http.client'], 'strict')

    assert_equal 'type', condition.key
    assert_equal ['http.client'], condition.values
    assert_equal 'strict', condition.match_type
  end

  def test_matches_with_category
    condition = Instana::SpanFiltering::Condition.new('category', ['protocols'], 'strict')

    assert condition.matches?(@http_span)
    refute condition.matches?(@redis_span)
  end

  def test_matches_with_kind
    condition = Instana::SpanFiltering::Condition.new('kind', [1], 'strict')

    assert condition.matches?(@http_span)
    refute condition.matches?(@redis_span)
  end

  def test_matches_with_type
    condition = Instana::SpanFiltering::Condition.new('type', ['http.client'], 'strict')

    assert condition.matches?(@http_span)
    refute condition.matches?(@redis_span)
  end

  def test_matches_with_nested_attribute
    condition = Instana::SpanFiltering::Condition.new('http.method', ['GET'], 'strict')

    assert condition.matches?(@http_span)
    refute condition.matches?(@redis_span)
  end

  def test_matches_with_wildcard_value
    condition = Instana::SpanFiltering::Condition.new('type', ['*'], 'strict')

    assert condition.matches?(@http_span)
    assert condition.matches?(@redis_span)
  end

  def test_match_type_strict
    condition = Instana::SpanFiltering::Condition.new('http.url', ['https://example.com/api'], 'strict')

    assert condition.matches?(@http_span)

    condition = Instana::SpanFiltering::Condition.new('http.url', ['https://example.com'], 'strict')
    refute condition.matches?(@http_span)
  end

  def test_match_type_startswith
    condition = Instana::SpanFiltering::Condition.new('http.url', ['https://example'], 'startswith')

    assert condition.matches?(@http_span)

    condition = Instana::SpanFiltering::Condition.new('http.url', ['http://example'], 'startswith')
    refute condition.matches?(@http_span)
  end

  def test_match_type_endswith
    condition = Instana::SpanFiltering::Condition.new('http.url', ['.com/api'], 'endswith')

    assert condition.matches?(@http_span)

    condition = Instana::SpanFiltering::Condition.new('http.url', ['.org/api'], 'endswith')
    refute condition.matches?(@http_span)
  end

  def test_match_type_contains
    condition = Instana::SpanFiltering::Condition.new('http.url', ['example.com'], 'contains')

    assert condition.matches?(@http_span)

    condition = Instana::SpanFiltering::Condition.new('http.url', ['example.org'], 'contains')
    refute condition.matches?(@http_span)
  end

  def test_multiple_values
    condition = Instana::SpanFiltering::Condition.new('type', ['http.client', 'redis'], 'strict')

    assert condition.matches?(@http_span)
    assert condition.matches?(@redis_span)
  end

  def test_non_existent_attribute
    condition = Instana::SpanFiltering::Condition.new('nonexistent', ['value'], 'strict')

    refute condition.matches?(@http_span)
  end

  def test_database_category_detection
    db_span = {
      n: 'mysql',
      k: 3,
      data: {
        mysql: {
          query: 'SELECT * FROM users'
        }
      }
    }

    condition = Instana::SpanFiltering::Condition.new('category', ['databases'], 'strict')
    assert condition.matches?(db_span)
  end

  def test_messaging_category_detection
    mq_span = {
      n: 'sqs',
      k: 3,
      data: {
        sqs: {
          queue: 'my-queue'
        }
      }
    }

    condition = Instana::SpanFiltering::Condition.new('category', ['messaging'], 'strict')
    assert condition.matches?(mq_span)
  end

  def test_match_type_default_fallback
    # Test that an invalid match_type falls back to 'strict'
    condition = Instana::SpanFiltering::Condition.new('http.url', ['https://example.com/api'], 'invalid_match_type')

    assert condition.matches?(@http_span)

    condition = Instana::SpanFiltering::Condition.new('http.url', ['different_url'], 'invalid_match_type')
    refute condition.matches?(@http_span)
  end

  def test_numeric_values
    # Test matching against numeric values
    status_span = {
      n: 'http.client',
      k: 1,
      data: {
        http: {
          status: 404,
          response_time: 123.45,
          success_rate: 0.99
        }
      }
    }

    # Test strict matching with integer value
    condition = Instana::SpanFiltering::Condition.new('http.status', [404], 'strict')
    assert condition.matches?(status_span)

    # Test strict matching with integer as string value
    condition = Instana::SpanFiltering::Condition.new('http.status', ['404'], 'strict')
    assert condition.matches?(status_span)

    # Test strict matching with wrong integer value
    condition = Instana::SpanFiltering::Condition.new('http.status', [200], 'strict')
    refute condition.matches?(status_span)

    # Test contains matching with numeric value (converted to string)
    condition = Instana::SpanFiltering::Condition.new('http.status', ['40'], 'contains')
    assert condition.matches?(status_span)

    # Test strict matching with float value
    condition = Instana::SpanFiltering::Condition.new('http.response_time', [123.45], 'strict')
    assert condition.matches?(status_span)

    # Test strict matching with float as string value
    condition = Instana::SpanFiltering::Condition.new('http.response_time', ['123.45'], 'strict')
    assert condition.matches?(status_span)
  end

  def test_boolean_values
    # Test matching against boolean values
    boolean_span = {
      n: 'custom',
      k: 1,
      data: {
        custom: {
          success: true,
          cached: false
        }
      }
    }

    # Test strict matching with boolean value
    condition = Instana::SpanFiltering::Condition.new('custom.success', [true], 'strict')
    assert condition.matches?(boolean_span)

    # Test strict matching with boolean as string value
    condition = Instana::SpanFiltering::Condition.new('custom.success', ['true'], 'strict')
    assert condition.matches?(boolean_span)

    # Test strict matching with wrong boolean value
    condition = Instana::SpanFiltering::Condition.new('custom.success', [false], 'strict')
    refute condition.matches?(boolean_span)

    # Test strict matching with false boolean value
    condition = Instana::SpanFiltering::Condition.new('custom.cached', [false], 'strict')
    assert condition.matches?(boolean_span)

    # Test strict matching with false as string value
    condition = Instana::SpanFiltering::Condition.new('custom.cached', ['false'], 'strict')
    assert condition.matches?(boolean_span)
  end

  def test_nested_symbol_keys_multiple_levels
    # Test with deeply nested symbol keys
    deep_span = {
      n: 'api',
      k: 1,
      data: {
        api: {
          request: {
            headers: {
              content_type: 'application/json'
            }
          }
        }
      }
    }

    # Test accessing deeply nested attributes
    condition = Instana::SpanFiltering::Condition.new('api.request.headers.content_type', ['application/json'], 'strict')
    assert condition.matches?(deep_span)
  end
end
