# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2016

require 'test_helper'
require 'rack/test'

framework_version = Gem::Specification.find_by_name('rack').version
if framework_version < Gem::Version.new('3.0.0')
  require 'rack/lobster'
else
  require 'rackup/lobster'
end

class RackTest < Minitest::Test
  include Rack::Test::Methods

  class PathTemplateApp
    def call(env)
      env['INSTANA_HTTP_PATH_TEMPLATE'] = 'sample_template'
      [200, {}, ['Ok']]
    end
  end

  class ErrorApp
    def call(_env)
      raise 'An Error'
    end
  end

  class FiveZeroOneApp
    def call(_env)
      [501, {}, ['No']]
    end
  end

  class NoHeadersApp
    def call(_env)
      [501, nil, ['No']]
    end
  end

  def app
    framework_version = Gem::Specification.find_by_name('rack').version
    @app = Rack::Builder.new do
      use Rack::CommonLogger
      use Rack::ShowExceptions
      use Instana::Rack
      if framework_version < Gem::Version.new('3.0.0')
        map("/mrlobster") { run Rack::Lobster.new }
      else
        map("/mrlobster") { run Rackup::Lobster.new }
      end
      map("/path_tpl") { run PathTemplateApp.new }
      map("/error") { run ErrorApp.new }
      map("/five_zero_one") { run FiveZeroOneApp.new }
    end
  end

  def test_config_defaults
    assert ::Instana.config[:rack].is_a?(Hash)
    assert ::Instana.config[:rack].key?(:enabled)
    assert_equal true, ::Instana.config[:rack][:enabled]

    activator = ::Instana::Activators::Rack.new
    assert_equal true, activator.can_instrument?
  end

  def test_instrumentation_disabled
    ::Instana.config[:rack][:enabled] = false

    activator = ::Instana::Activators::Rack.new
    assert_equal false, activator.can_instrument?
  end

  def test_basic_get
    clear_all!
    ::Instana.config[:collect_backtraces] = true

    get '/mrlobster'
    assert last_response.ok?

    spans = ::Instana.processor.queued_spans

    # Span validation
    assert_equal 1, spans.count

    rack_span = spans.first
    assert_equal :rack, rack_span[:n]

    assert last_response.headers.key?("X-Instana-T")
    assert last_response.headers["X-Instana-T"] == ::Instana::Util.id_to_header(rack_span[:t])
    assert last_response.headers.key?("X-Instana-S")
    assert last_response.headers["X-Instana-S"] == ::Instana::Util.id_to_header(rack_span[:s])
    assert last_response.headers.key?("X-Instana-L")
    assert last_response.headers["X-Instana-L"] == '1'
    assert last_response.headers.key?("Server-Timing")
    assert last_response.headers["Server-Timing"] == "intid;desc=#{::Instana::Util.id_to_header(rack_span[:t])}"

    # W3C Trace Context
    assert_equal "00-#{rack_span[:t].rjust(32, '0')}-#{rack_span[:s]}-01", last_response.headers["Traceparent"]
    assert_equal "in=#{rack_span[:t]};#{rack_span[:s]}", last_response.headers["Tracestate"]

    assert rack_span.key?(:data)
    assert rack_span[:data].key?(:http)
    assert_equal "GET", rack_span[:data][:http][:method]
    assert_equal "/mrlobster", rack_span[:data][:http][:url]
    assert_equal 200, rack_span[:data][:http][:status]
    assert_equal 'example.org', rack_span[:data][:http][:host]
    assert rack_span.key?(:f)
    assert !rack_span.key?(:stack)

    # Restore to default
    ::Instana.config[:collect_backtraces] = false
  end

  def test_basic_get_with_custom_service_name
    ENV['INSTANA_SERVICE_NAME'] = 'WalterBishop'

    clear_all!
    get '/mrlobster'
    assert last_response.ok?

    spans = ::Instana.processor.queued_spans

    # Span validation
    assert_equal 1, spans.count

    rack_span = spans.first
    assert_equal 'WalterBishop', rack_span[:data][:service]

    ENV.delete('INSTANA_SERVICE_NAME')
  end

  def test_basic_post
    clear_all!
    post '/mrlobster'
    assert last_response.ok?

    spans = ::Instana.processor.queued_spans

    # Span validation
    assert_equal 1, spans.count
    rack_span = spans.first
    assert_equal :rack, rack_span[:n]

    assert last_response.headers.key?("X-Instana-T")
    assert last_response.headers["X-Instana-T"] == ::Instana::Util.id_to_header(rack_span[:t])
    assert last_response.headers.key?("X-Instana-S")
    assert last_response.headers["X-Instana-S"] == ::Instana::Util.id_to_header(rack_span[:s])
    assert last_response.headers.key?("X-Instana-L")
    assert last_response.headers["X-Instana-L"] == '1'
    assert last_response.headers.key?("Server-Timing")
    assert last_response.headers["Server-Timing"] == "intid;desc=#{::Instana::Util.id_to_header(rack_span[:t])}"

    assert rack_span.key?(:data)
    assert rack_span[:data].key?(:http)
    assert_equal "POST", rack_span[:data][:http][:method]
    assert_equal "/mrlobster", rack_span[:data][:http][:url]
    assert_equal 200, rack_span[:data][:http][:status]
    assert rack_span.key?(:f)
  end

  def test_basic_put
    clear_all!
    put '/mrlobster'
    assert last_response.ok?

    spans = ::Instana.processor.queued_spans

    # Span validation
    assert_equal 1, spans.count
    rack_span = spans.first
    assert_equal :rack, rack_span[:n]

    assert last_response.headers.key?("X-Instana-T")
    assert last_response.headers["X-Instana-T"] == ::Instana::Util.id_to_header(rack_span[:t])
    assert last_response.headers.key?("X-Instana-S")
    assert last_response.headers["X-Instana-S"] == ::Instana::Util.id_to_header(rack_span[:s])
    assert last_response.headers.key?("X-Instana-L")
    assert last_response.headers["X-Instana-L"] == '1'
    assert last_response.headers.key?("Server-Timing")
    assert last_response.headers["Server-Timing"] == "intid;desc=#{::Instana::Util.id_to_header(rack_span[:t])}"

    assert rack_span.key?(:data)
    assert rack_span[:data].key?(:http)
    assert_equal "PUT", rack_span[:data][:http][:method]
    assert_equal "/mrlobster", rack_span[:data][:http][:url]
    assert_equal 200, rack_span[:data][:http][:status]
    assert rack_span.key?(:f)
  end

  def test_context_continuation
    clear_all!
    continuation_id = Instana::Util.generate_id
    header 'X-INSTANA-T', continuation_id
    header 'X-INSTANA-S', continuation_id

    get '/mrlobster'
    assert last_response.ok?

    spans = ::Instana.processor.queued_spans

    # Span validation
    assert_equal 1, spans.count
    rack_span = spans.first
    assert_equal :rack, rack_span[:n]

    assert last_response.headers.key?("X-Instana-T")
    assert last_response.headers["X-Instana-T"] == ::Instana::Util.id_to_header(rack_span[:t])
    assert last_response.headers.key?("X-Instana-S")
    assert last_response.headers["X-Instana-S"] == ::Instana::Util.id_to_header(rack_span[:s])
    assert last_response.headers.key?("X-Instana-L")
    assert last_response.headers["X-Instana-L"] == '1'
    assert last_response.headers.key?("Server-Timing")
    assert last_response.headers["Server-Timing"] == "intid;desc=#{::Instana::Util.id_to_header(rack_span[:t])}"

    assert rack_span.key?(:data)
    assert rack_span[:data].key?(:http)
    assert_equal "GET", rack_span[:data][:http][:method]
    assert_equal "/mrlobster", rack_span[:data][:http][:url]
    assert_equal 200, rack_span[:data][:http][:status]
    assert rack_span.key?(:f)

    # Context validation
    # The first span should have the passed in trace ID
    # and specify the passed in span ID as it's parent.
    assert_equal continuation_id, rack_span[:t]
    assert_equal continuation_id, rack_span[:p]
  end

  def test_correlation_information
    clear_all!

    header 'X-INSTANA-L', '1,correlationType=test;correlationId=abcdefh123'

    get '/mrlobster'
    assert last_response.ok?

    spans = ::Instana.processor.queued_spans

    # Span validation
    assert_equal 1, spans.count
    rack_span = spans.first
    assert_equal :rack, rack_span[:n]

    assert_equal 'abcdefh123', rack_span[:crid]
    assert_equal 'test', rack_span[:crtp]
  end


  def test_instana_response_headers
    clear_all!
    get '/mrlobster'
    assert last_response.ok?

    refute_nil last_response.headers.key?("X-Instana-T")
    refute_nil last_response.headers.key?("X-Instana-S")
  end

  def test_that_url_params_not_logged
    clear_all!
    get '/mrlobster?blah=2&wilma=1&betty=2;fred=3'

    spans = ::Instana.processor.queued_spans
    assert_equal 1, spans.length

    refute_nil spans.first.key?(:data)
    refute_nil spans.first[:data].key?(:http)
    refute_nil spans.first[:data][:http].key?(:url)
    assert_equal '/mrlobster', spans.first[:data][:http][:url]

    assert last_response.ok?
  end

  def test_custom_headers_capture
    clear_all!
    ::Instana.config[:collect_backtraces] = true
    ::Instana.agent.define_singleton_method(:extra_headers) { %w(X-Capture-This X-Capture-That) }

    get '/mrlobster', {}, { "HTTP_X_CAPTURE_THIS" => "ThereYouGo" }
    assert last_response.ok?
    assert_equal "ThereYouGo", last_request.env["HTTP_X_CAPTURE_THIS"]

    spans = ::Instana.processor.queued_spans

    # Span validation
    assert_equal 1, spans.count
    rack_span = spans.first

    assert rack_span[:data][:http].key?(:header)
    assert rack_span[:data][:http][:header].key?(:"X-Capture-This")
    assert !rack_span[:data][:http][:header].key?(:"X-Capture-That")
    assert_equal "ThereYouGo", rack_span[:data][:http][:header][:"X-Capture-This"]
    assert !rack_span.key?(:stack)

    # Restore to default
    ::Instana.config[:collect_backtraces] = false
    ::Instana.agent.singleton_class.send(:remove_method, :extra_headers)
  end

  def test_capture_http_path_template
    clear_all!

    get '/path_tpl'
    assert last_response.ok?

    spans = ::Instana.processor.queued_spans
    assert_equal 1, spans.length

    rack_span = spans.first
    assert_equal :rack, rack_span[:n]
    assert_equal 'sample_template', rack_span[:data][:http][:path_tpl]
  end

  def test_basic_get_with_x_instana_synthetic
    header 'X-INSTANA-SYNTHETIC', '1'

    clear_all!
    get '/mrlobster'
    assert last_response.ok?

    spans = ::Instana.processor.queued_spans

    # Span validation
    assert_equal 1, spans.count

    first_span = spans.first
    assert_equal true, first_span[:sy]
  end

  def test_basic_get_with_w3c_trace
    clear_all!

    header 'TRACEPARENT', '00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01'

    get '/mrlobster'
    assert last_response.ok?

    spans = ::Instana.processor.queued_spans
    assert_equal 1, spans.count

    first_span = spans.first
    assert_equal :rack, first_span[:n]
    assert_equal 'a3ce929d0e0e4736', first_span[:t]
    assert_equal '00f067aa0ba902b7', first_span[:p]
    assert_equal '4bf92f3577b34da6a3ce929d0e0e4736', first_span[:lt]
    assert_nil first_span[:ia]
    assert first_span[:tp]
  end

  def test_basic_get_with_w3c_disabled
    clear_all!
    ::Instana.config[:w3c_trace_correlation] = false

    header 'TRACEPARENT', '00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01'

    get '/mrlobster'
    assert last_response.ok?

    spans = ::Instana.processor.queued_spans
    assert_equal 1, spans.count

    first_span = spans.first
    assert_equal :rack, first_span[:n]
    refute first_span[:tp]
    ::Instana.config[:w3c_trace_correlation] = true
  end

  def test_skip_trace
    clear_all!
    header 'X_INSTANA_L', '0;junk'

    get '/mrlobster'
    assert last_response.ok?

    spans = ::Instana.processor.queued_spans
    assert_equal 0, spans.count
  end

  def test_disable_trace
    clear_all!
    ::Instana.config[:tracing][:enabled] = false

    get '/mrlobster'
    assert last_response.ok?

    spans = ::Instana.processor.queued_spans
    assert_equal 0, spans.count
    ::Instana.config[:tracing][:enabled] = true
  end

  def test_error_trace
    clear_all!

    get '/error'
    refute last_response.ok?

    spans = ::Instana.processor.queued_spans
    assert_equal 1, spans.count

    first_span = spans.first
    assert_equal :rack, first_span[:n]
    assert_equal 1, first_span[:ec]
  end

  def test_disable_trace_with_error
    clear_all!
    ::Instana.config[:tracing][:enabled] = false

    get '/error'
    refute last_response.ok?

    spans = ::Instana.processor.queued_spans
    assert_equal 0, spans.count
    ::Instana.config[:tracing][:enabled] = true
  end

  def test_five_zero_x_trace
    clear_all!

    get '/five_zero_one'
    refute last_response.ok?

    spans = ::Instana.processor.queued_spans
    assert_equal 1, spans.count

    first_span = spans.first
    assert_equal :rack, first_span[:n]
    assert_equal 1, first_span[:ec]
  end
end
