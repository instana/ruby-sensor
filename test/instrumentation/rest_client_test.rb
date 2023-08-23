# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2016

require 'test_helper'
require 'support/apps/http_endpoint/boot'

class RestClientTest < Minitest::Test
  def setup
    # See https://github.com/rest-client/rest-client/issues/612
    OpenSSL::SSL::SSLContext::DEFAULT_PARAMS[:ciphers] = OpenSSL::SSL::SSLContext.new.ciphers
  end

  def test_config_defaults
    assert ::Instana.config[:'rest-client'].is_a?(Hash)
    assert ::Instana.config[:'rest-client'].key?(:enabled)
    assert_equal true, ::Instana.config[:'rest-client'][:enabled]

    activator = ::Instana::Activators::RestClient.new
    assert_equal true, activator.can_instrument?
  end

  def test_instrumentation_disabled
    ::Instana.config[:'rest-client'][:enabled] = false

    activator = ::Instana::Activators::RestClient.new
    assert_equal false, activator.can_instrument?
  end

  def test_basic_get
    clear_all!
    WebMock.allow_net_connect!

    url = "http://127.0.0.1:6511/"

    Instana.tracer.start_or_continue_trace('restclient-test') do
      RestClient.get url
    end

    spans = ::Instana.processor.queued_spans
    assert_equal 4, spans.length

    rack_span = find_first_span_by_name(spans, :rack)
    sdk_span = find_first_span_by_name(spans, :'restclient-test')
    rest_span = find_first_span_by_name(spans, :'rest-client')
    net_span = find_first_span_by_name(spans, :'net-http')

    validate_sdk_span(sdk_span, {:name => :'restclient-test', :type => :entry})
    validate_sdk_span(rest_span, {:name => :'rest-client', :type => :intermediate})

    # Span name validation
    assert_equal :rack, rack_span[:n]
    assert_equal :sdk, sdk_span[:n]
    assert_equal :sdk, rest_span[:n]
    assert_equal :"net-http", net_span[:n]

    # Trace IDs and relationships
    trace_id = sdk_span[:t]
    assert_equal trace_id, rest_span[:t]
    assert_equal trace_id, net_span[:t]
    assert_equal trace_id, rack_span[:t]

    assert_equal sdk_span[:s], rest_span[:p]
    assert_equal rest_span[:s], net_span[:p]
    assert_equal net_span[:s], rack_span[:p]

    # data keys/values
    refute_nil net_span.key?(:data)
    refute_nil net_span[:data].key?(:http)
    assert_equal "http://127.0.0.1:6511/", net_span[:data][:http][:url]
    assert_equal "200", net_span[:data][:http][:status]

    WebMock.disable_net_connect!
  end
end
