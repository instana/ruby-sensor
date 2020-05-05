
if defined?(::Sinatra)
  require 'test_helper'
  require File.expand_path(File.dirname(__FILE__) + '/../apps/sinatra')
  require 'rack/test'

  class SinatraTest < Minitest::Test
    include Rack::Test::Methods

    def app
      InstanaSinatraApp
    end

    def test_basic_get
      clear_all!

      r = get '/'
      assert last_response.ok?

      assert r.headers.key?("X-Instana-T")
      assert r.headers.key?("X-Instana-S")

      spans = ::Instana.processor.queued_spans
      assert_equal 1, spans.count

      first_span = spans.first
      assert_equal :rack, first_span[:n]
      assert first_span.key?(:data)
      assert first_span[:data].key?(:http)

      assert first_span[:data][:http].key?(:method)
      assert_equal "GET", first_span[:data][:http][:method]

      assert first_span[:data][:http].key?(:url)
      assert_equal "/", first_span[:data][:http][:url]

      assert first_span[:data][:http].key?(:status)
      assert_equal 200, first_span[:data][:http][:status]

      assert first_span[:data][:http].key?(:host)
      assert_equal "example.org", first_span[:data][:http][:host]
    end

    def test_synthetic
      clear_all!

      r = get '/hello'
      assert last_response.ok?

      assert r.headers.key?("X-Instana-T")
      assert r.headers.key?("X-Instana-S")

      spans = ::Instana.processor.queued_spans
      assert_equal 1, spans.count

      first_span = spans.first
      assert_equal :rack, first_span[:n]
      assert first_span.key?(:data)
      assert first_span[:data].key?(:sy)
      assert_equal true, first_span[:data][:sy]
    end
  end
end
