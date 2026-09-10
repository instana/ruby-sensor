# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2016

require 'test_helper'
require 'support/apps/http_endpoint/boot'

class RestClientTest < Minitest::Test
  def setup
    # See https://github.com/rest-client/rest-client/issues/612
    OpenSSL::SSL::SSLContext::DEFAULT_PARAMS[:ciphers] = OpenSSL::SSL::SSLContext.new.ciphers if Gem::Version.new(RUBY_VERSION) < Gem::Version.new('4.0')
  end

  def teardown
    ::Instana.config[:allow_exit_as_root] = false
  end

  def test_config_defaults
    assert ::Instana.config[:'rest-client'].is_a?(Hash)
    assert ::Instana.config[:'rest-client'].key?(:enabled)
    assert_equal true, ::Instana.config[:'rest-client'][:enabled]
  end

  def test_basic_get
    clear_all!
    WebMock.allow_net_connect!

    url = "http://127.0.0.1:6511/"

    Instana.tracer.in_span('restclient-test') do
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

  def test_basic_get_as_root_exit_span
    clear_all!
    ::Instana.config[:allow_exit_as_root] = true
    WebMock.allow_net_connect!

    url = "http://127.0.0.1:6511/"

    RestClient.get url

    spans = ::Instana.processor.queued_spans
    assert_equal 3, spans.length

    rack_span = find_first_span_by_name(spans, :rack)
    rest_span = find_first_span_by_name(spans, :'rest-client')
    net_span = find_first_span_by_name(spans, :'net-http')
    # Span name validation
    assert_equal :rack, rack_span[:n]
    assert_equal :sdk, rest_span[:n]
    assert_equal :"net-http", net_span[:n]

    # Trace IDs and relationships
    trace_id = net_span[:t]
    assert_equal trace_id, rest_span[:t]
    assert_equal trace_id, rack_span[:t]

    assert_nil rest_span[:p]
    assert_equal rest_span[:s], net_span[:p]
    assert_equal net_span[:s], rack_span[:p]

    # data keys/values
    refute_nil net_span.key?(:data)
    refute_nil net_span[:data].key?(:http)
    assert_equal "http://127.0.0.1:6511/", net_span[:data][:http][:url]
    assert_equal "200", net_span[:data][:http][:status]

    WebMock.disable_net_connect!
  end

  def test_no_error_is_raised_and_no_spans_are_created_when_agent_is_not_ready
    clear_all!
    error = nil
    WebMock.allow_net_connect!

    url = "http://127.0.0.1:6511/"

    ::Instana.agent.stub(:ready?, false) do
      assert_silent do
        RestClient.get url
      rescue StandardError => e
        error = e
      end
    end

    assert_nil error
    assert_empty ::Instana.processor.queued_spans

    WebMock.disable_net_connect!
  end
end

class RestClient4xxClassificationTest < Minitest::Test
  include Instana::TestHelpers

  def setup
    @orig_classify_all   = ::Instana.config[:http_exit_classify_all_4xx_as_errors]
    @orig_classify_codes = ::Instana.config[:http_exit_classify_as_errors]
  end

  def teardown
    ::Instana.config[:http_exit_classify_all_4xx_as_errors] = @orig_classify_all
    ::Instana.config[:http_exit_classify_as_errors]         = @orig_classify_codes
    WebMock.disable_net_connect!
  end

  # Helper: fire a RestClient GET, swallowing ExceptionWithResponse so the
  # test can inspect spans regardless of whether RestClient raised.
  def get_ignoring_http_errors(url)
    RestClient.get(url)
  rescue RestClient::ExceptionWithResponse
    nil
  end

  def test_4xx_rest_client_span_not_errored_by_default
    clear_all!
    WebMock.allow_net_connect!
    ::Instana.config[:http_exit_classify_all_4xx_as_errors] = false
    ::Instana.config[:http_exit_classify_as_errors]         = []

    Instana.tracer.in_span(:'restclient-4xx-test') do
      get_ignoring_http_errors('http://127.0.0.1:6511/status/401')
    end

    spans = ::Instana.processor.queued_spans
    rc_span   = find_first_span_by_name(spans, :'rest-client')
    http_span = find_first_span_by_name(spans, :'net-http')

    assert_nil rc_span[:error],   'rest-client span must not be errored in default mode'
    assert_nil http_span[:error], 'net-http span must not be errored in default mode'
  end

  def test_4xx_both_spans_errored_when_classify_all_is_true
    clear_all!
    WebMock.allow_net_connect!
    ::Instana.config[:http_exit_classify_all_4xx_as_errors] = true
    ::Instana.config[:http_exit_classify_as_errors]         = []

    Instana.tracer.in_span(:'restclient-4xx-test') do
      get_ignoring_http_errors('http://127.0.0.1:6511/status/401')
    end

    spans = ::Instana.processor.queued_spans
    rc_span   = find_first_span_by_name(spans, :'rest-client')
    http_span = find_first_span_by_name(spans, :'net-http')

    assert_equal true, rc_span[:error],   'rest-client span must be errored'
    assert_equal true, http_span[:error], 'net-http span must be errored'
  end

  def test_listed_code_errors_both_spans
    clear_all!
    WebMock.allow_net_connect!
    ::Instana.config[:http_exit_classify_all_4xx_as_errors] = false
    ::Instana.config[:http_exit_classify_as_errors]         = [401]

    Instana.tracer.in_span(:'restclient-4xx-test') do
      get_ignoring_http_errors('http://127.0.0.1:6511/status/401')
    end

    spans = ::Instana.processor.queued_spans
    rc_span   = find_first_span_by_name(spans, :'rest-client')
    http_span = find_first_span_by_name(spans, :'net-http')

    assert_equal true, rc_span[:error]
    assert_equal true, http_span[:error]
  end

  def test_unlisted_code_does_not_error_either_span
    clear_all!
    WebMock.allow_net_connect!
    ::Instana.config[:http_exit_classify_all_4xx_as_errors] = false
    ::Instana.config[:http_exit_classify_as_errors]         = [401]

    Instana.tracer.in_span(:'restclient-4xx-test') do
      get_ignoring_http_errors('http://127.0.0.1:6511/status/404')
    end

    spans = ::Instana.processor.queued_spans
    rc_span   = find_first_span_by_name(spans, :'rest-client')
    http_span = find_first_span_by_name(spans, :'net-http')

    assert_nil rc_span[:error],   'rest-client span must not be errored for unlisted code'
    assert_nil http_span[:error], 'net-http span must not be errored for unlisted code'
  end
end
