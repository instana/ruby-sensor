# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2016

require 'test_helper'
require 'support/apps/http_endpoint/boot'

class ExconTest < Minitest::Test
  def test_config_defaults
    assert ::Instana.config[:excon].is_a?(Hash)
    assert ::Instana.config[:excon].key?(:enabled)
    assert_equal true, ::Instana.config[:excon][:enabled]
  end

  def test_basic_get
    clear_all!

    # A slight hack but webmock chokes with pipelined requests.
    # Delete their excon middleware
    Excon.defaults[:middlewares].delete ::WebMock::HttpLibAdapters::ExconAdapter
    Excon.defaults[:middlewares].delete ::Excon::Middleware::Mock

    url = "http://127.0.0.1:6511"

    connection = Excon.new(url)
    Instana.tracer.start_or_continue_trace('excon-test') do
      connection.get(:path => '/?basic_get')
    end

    spans = ::Instana.processor.queued_spans
    assert_equal 3, spans.length

    sdk_span = find_first_span_by_name(spans, :'excon-test')
    excon_span = find_first_span_by_name(spans, :excon)
    rack_span = find_first_span_by_name(spans, :rack)

    validate_sdk_span(sdk_span, {:name => :'excon-test', :type => :entry})

    # data keys/values
    refute_nil excon_span.key?(:data)
    refute_nil excon_span[:data].key?(:http)
    assert_equal "http://127.0.0.1:6511/", excon_span[:data][:http][:url]
    assert_equal 200, excon_span[:data][:http][:status]

    # excon backtrace not included by default check
    assert !excon_span.key?(:stack)

    assert_equal sdk_span[:t], excon_span[:t]
    assert_equal rack_span[:t], excon_span[:t]

    assert_equal rack_span[:p], excon_span[:s]
    assert_equal excon_span[:p], sdk_span[:s]
  end

  def test_basic_get_with_error
    clear_all!

    # A slight hack but webmock chokes with pipelined requests.
    # Delete their excon middleware
    Excon.defaults[:middlewares].delete ::WebMock::HttpLibAdapters::ExconAdapter
    Excon.defaults[:middlewares].delete ::Excon::Middleware::Mock

    url = "http://127.0.0.1:6511"

    begin
      connection = Excon.new(url)
      Instana.tracer.start_or_continue_trace('excon-test') do
        connection.get(:path => '/error')
      end
    rescue
    end

    spans = ::Instana.processor.queued_spans
    assert_equal 3, spans.length

    rack_span = find_first_span_by_name(spans, :rack)
    excon_span = find_first_span_by_name(spans, :excon)
    sdk_span = find_first_span_by_name(spans, :'excon-test')

    validate_sdk_span(sdk_span, {:name => :'excon-test', :type => :entry})

    assert_equal sdk_span[:s], excon_span[:p]
    assert_equal excon_span[:s], rack_span[:p]

    assert_equal :excon, excon_span[:n]
    refute_nil excon_span.key?(:data)
    refute_nil excon_span[:data].key?(:http)
    assert_equal "http://127.0.0.1:6511/error", excon_span[:data][:http][:url]
    assert_equal 500, excon_span[:data][:http][:status]

    # error validation
    assert_equal true, excon_span[:error]
    assert_equal 1, excon_span[:ec]
  end

  def test_pipelined_requests
    clear_all!

    # A slight hack but webmock chokes with pipelined requests.
    # Delete their excon middleware
    Excon.defaults[:middlewares].delete ::WebMock::HttpLibAdapters::ExconAdapter
    Excon.defaults[:middlewares].delete ::Excon::Middleware::Mock

    url = "http://127.0.0.1:6511"

    connection = Excon.new(url)
    request = { :method => :get, :path => '/?pipelined_request' }
    Instana.tracer.start_or_continue_trace('excon-test') do
      connection.requests([request, request, request])
    end

    spans = ::Instana.processor.queued_spans
    assert_equal 7, spans.length

    rack_spans = find_spans_by_name(spans, :rack)
    excon_spans = find_spans_by_name(spans, :excon)
    sdk_span = find_first_span_by_name(spans, :'excon-test')

    validate_sdk_span(sdk_span, {:name => :'excon-test', :type => :entry})

    assert_equal 3, rack_spans.length
    assert_equal 3, excon_spans.length

    for rack_span in rack_spans
      # data keys/values
      refute_nil rack_span.key?(:data)
      refute_nil rack_span[:data].key?(:http)
      assert_equal "/", rack_span[:data][:http][:url]
      assert_equal 200, rack_span[:data][:http][:status]
      assert !rack_span.key?(:stack)

      # Make sure a parent is specified and that we have it
      refute_nil rack_span[:p]
      excon_span = find_span_by_id(spans, rack_span[:p])
      assert_equal :excon, excon_span[:n]

      refute_nil excon_span.key?(:data)
      refute_nil excon_span[:data].key?(:http)
      assert_equal "http://127.0.0.1:6511/", excon_span[:data][:http][:url]
      assert_equal 200, excon_span[:data][:http][:status]
      assert !excon_span.key?(:stack)

      # walk up the line
      refute_nil excon_span[:p]
      grandparent_span = find_span_by_id(spans, excon_span[:p])
      assert_nil grandparent_span[:p]
      assert_equal :sdk, grandparent_span[:n]
    end
  end
end
