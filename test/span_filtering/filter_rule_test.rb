# (c) Copyright IBM Corp. 2025

require 'test_helper'

class FilterRuleTest < Minitest::Test
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

    @condition_http = Instana::SpanFiltering::Condition.new('type', ['http.client'], 'strict')
    @condition_get = Instana::SpanFiltering::Condition.new('http.method', ['GET'], 'strict')
    @condition_redis = Instana::SpanFiltering::Condition.new('type', ['redis'], 'strict')
  end

  def test_initialization
    rule = Instana::SpanFiltering::FilterRule.new('test-rule', true, [@condition_http])

    assert_equal 'test-rule', rule.name
    assert_equal true, rule.suppression
    assert_equal [@condition_http], rule.conditions
  end

  def test_matches_with_single_condition
    rule = Instana::SpanFiltering::FilterRule.new('http-rule', true, [@condition_http])

    assert rule.matches?(@http_span)
    refute rule.matches?(@redis_span)
  end

  def test_matches_with_multiple_conditions_all_match
    rule = Instana::SpanFiltering::FilterRule.new('http-get-rule', true, [@condition_http, @condition_get])

    assert rule.matches?(@http_span)
    refute rule.matches?(@redis_span)
  end

  def test_matches_with_multiple_conditions_partial_match
    # Create a condition that won't match the HTTP span
    condition_post = Instana::SpanFiltering::Condition.new('http.method', ['POST'], 'strict')
    rule = Instana::SpanFiltering::FilterRule.new('http-post-rule', true, [@condition_http, condition_post])

    refute rule.matches?(@http_span)
    refute rule.matches?(@redis_span)
  end

  def test_matches_with_no_conditions
    rule = Instana::SpanFiltering::FilterRule.new('empty-rule', true, [])

    assert rule.matches?(@http_span)
    assert rule.matches?(@redis_span)
  end

  def test_update_suppression
    rule = Instana::SpanFiltering::FilterRule.new('test-rule', true, [@condition_http])
    assert_equal true, rule.suppression

    rule.suppression = false
    assert_equal false, rule.suppression
  end

  def test_update_conditions
    rule = Instana::SpanFiltering::FilterRule.new('test-rule', true, [@condition_http])
    assert_equal [@condition_http], rule.conditions

    rule.conditions = [@condition_redis]
    assert_equal [@condition_redis], rule.conditions

    refute rule.matches?(@http_span)
    assert rule.matches?(@redis_span)
  end

  def test_matches_with_mixed_key_types
    # Create a span with mixed string and symbol keys
    mixed_key_span = {
      n: 'http.client',
      'k' => 1,
      data: {
        http: {
          url: 'https://example.com/api',
          'method' => 'POST'
        }
      }
    }

    # Test with condition that should match
    condition_http_any = Instana::SpanFiltering::Condition.new('type', ['http.client'], 'strict')
    rule = Instana::SpanFiltering::FilterRule.new('mixed-key-rule', true, [condition_http_any])
    assert rule.matches?(mixed_key_span)

    # Test with condition that should match nested attribute with symbol key
    condition_url = Instana::SpanFiltering::Condition.new('http.url', ['https://example.com/api'], 'strict')
    rule = Instana::SpanFiltering::FilterRule.new('url-rule', true, [condition_url])
    assert rule.matches?(mixed_key_span)

    # Test with condition that should match nested attribute with string key
    condition_method = Instana::SpanFiltering::Condition.new('http.method', ['POST'], 'strict')
    rule = Instana::SpanFiltering::FilterRule.new('method-rule', true, [condition_method])
    assert rule.matches?(mixed_key_span)
  end
end
