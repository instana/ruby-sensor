require 'rack/test'
require 'rack/lobster'
require "instana/rack"

class RackTest < Minitest::Test
  include Rack::Test::Methods

  def app
    @app = Rack::Builder.new {
      use Rack::CommonLogger
      use Rack::ShowExceptions
      use Instana::Rack
      map "/mrlobster" do
        run Rack::Lobster.new
      end
    }
  end

  def test_basic_get
    get '/mrlobster'
    assert last_response.ok?

    spans = ::Instana.processor.queued_spans

    # Span validation
    assert_equal 1, spans.count
    first_span = spans.first
    assert_equal :rack, first_span[:n]
    assert_equal :ruby, first_span[:ta]
    assert first_span.key?(:data)
    assert first_span[:data].key?(:http)
    assert_equal "GET", first_span[:data][:http][:method]
    assert_equal "/mrlobster", first_span[:data][:http][:url]
    assert_equal 200, first_span[:data][:http][:status]
    assert first_span.key?(:f)
    assert first_span[:f].key?(:e)
    assert first_span[:f].key?(:h)
    assert_equal ::Instana.agent.agent_uuid, first_span[:f][:h]
    ::Instana.processor.clear!
  end

  def test_basic_post
    post '/mrlobster'
    assert last_response.ok?

    spans = ::Instana.processor.queued_spans

    # Span validation
    assert_equal 1, spans.count
    first_span = spans.first
    assert_equal :rack, first_span[:n]
    assert_equal :ruby, first_span[:ta]
    assert first_span.key?(:data)
    assert first_span[:data].key?(:http)
    assert_equal "POST", first_span[:data][:http][:method]
    assert_equal "/mrlobster", first_span[:data][:http][:url]
    assert_equal 200, first_span[:data][:http][:status]
    assert first_span.key?(:f)
    assert first_span[:f].key?(:e)
    assert first_span[:f].key?(:h)
    assert_equal ::Instana.agent.agent_uuid, first_span[:f][:h]
    ::Instana.processor.clear!
  end

  def test_basic_put
    put '/mrlobster'
    assert last_response.ok?

    spans = ::Instana.processor.queued_spans

    # Span validation
    assert_equal 1, spans.count
    first_span = spans.first
    assert_equal :rack, first_span[:n]
    assert_equal :ruby, first_span[:ta]
    assert first_span.key?(:data)
    assert first_span[:data].key?(:http)
    assert_equal "PUT", first_span[:data][:http][:method]
    assert_equal "/mrlobster", first_span[:data][:http][:url]
    assert_equal 200, first_span[:data][:http][:status]
    assert first_span.key?(:f)
    assert first_span[:f].key?(:e)
    assert first_span[:f].key?(:h)
    assert_equal ::Instana.agent.agent_uuid, first_span[:f][:h]
    ::Instana.processor.clear!
  end

  def test_get_with_context
    header 'X-INSTANA-T', "1234"
    header 'X-INSTANA-S', "4321"

    get '/mrlobster'
    assert last_response.ok?

    spans = ::Instana.processor.queued_spans

    # Span validation
    assert_equal 1, spans.count
    first_span = spans.first
    assert_equal :rack, first_span[:n]
    assert_equal :ruby, first_span[:ta]
    assert first_span.key?(:data)
    assert first_span[:data].key?(:http)
    assert_equal "GET", first_span[:data][:http][:method]
    assert_equal "/mrlobster", first_span[:data][:http][:url]
    assert_equal 200, first_span[:data][:http][:status]
    assert first_span.key?(:f)
    assert first_span[:f].key?(:e)
    assert first_span[:f].key?(:h)
    assert_equal ::Instana.agent.agent_uuid, first_span[:f][:h]

    # Context validation
    assert_equal "1234", first_span[:t]
    assert_equal "4321", first_span[:p]
    ::Instana.processor.clear!
  end

end
