require 'sinatra'
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


      spans = ::Instana.processor.queued_spans
      assert_equal 1, spans.count

      rack_span = spans.first
      assert_equal :rack, rack_span[:n]
      # ::Instana::Util.pry!

      assert r.headers.key?("X-Instana-T")
      assert r.headers["X-Instana-T"] == ::Instana::Util.id_to_header(rack_span[:t])
      assert r.headers.key?("X-Instana-S")
      assert r.headers["X-Instana-S"] == ::Instana::Util.id_to_header(rack_span[:s])
      assert r.headers.key?("X-Instana-L")
      assert r.headers["X-Instana-L"] == '1'
      assert r.headers.key?("Server-Timing")
      assert r.headers["Server-Timing"] == "intid;desc=#{::Instana::Util.id_to_header(rack_span[:t])}"
      
      assert rack_span.key?(:data)
      assert rack_span[:data].key?(:http)
      assert rack_span[:data][:http].key?(:method)
      assert_equal "GET", rack_span[:data][:http][:method]

      assert rack_span[:data][:http].key?(:url)
      assert_equal "/", rack_span[:data][:http][:url]

      assert rack_span[:data][:http].key?(:status)
      assert_equal 200, rack_span[:data][:http][:status]

      assert rack_span[:data][:http].key?(:host)
      assert_equal "example.org", rack_span[:data][:http][:host]
    end
    
    def test_path_template
      clear_all!

      r = get '/greet/instana'
      assert last_response.ok?

      spans = ::Instana.processor.queued_spans
      assert_equal 1, spans.count

      first_span = spans.first
      assert_equal :rack, first_span[:n]
      assert_equal '/greet/:name', first_span[:data][:http][:path_tpl]
    end
  end
end
