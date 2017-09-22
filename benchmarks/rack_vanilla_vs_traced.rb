require "bundler"

require 'rack'
require 'rack/builder'
require 'rack/handler/puma'
require 'net/http'
require "benchmark"
require "cgi"
Bundler.require(:default)
require "instana/rack"

Thread.new do
  app = Rack::Builder.new {
    map "/" do
      run Proc.new { |env|
        [200, {"Content-Type" => "application/json"}, ["[\"Stan\",\"is\",\"on\",\"the\",\"scene!\"]"]]
      }
    end
    map "/error" do
      run Proc.new { |env|
        [500, {"Content-Type" => "application/json"}, ["[\"Stan\",\"is\",\"on\",\"the\",\"error!\"]"]]
      }
    end
  }

  Rack::Handler::Puma.run(app, {:Host => '127.0.0.1', :Port => 7011})
end

Thread.new do
  app = Rack::Builder.new {
    use ::Instana::Rack
    map "/" do
      run Proc.new { |env|
        [200, {"Content-Type" => "application/json"}, ["[\"Stan\",\"is\",\"on\",\"the\",\"scene!\"]"]]
      }
    end
    map "/error" do
      run Proc.new { |env|
        [500, {"Content-Type" => "application/json"}, ["[\"Stan\",\"is\",\"on\",\"the\",\"error!\"]"]]
      }
    end
  }

  Rack::Handler::Puma.run(app, {:Host => '127.0.0.1', :Port => 7012})
end

sleep(2)
puts "Rack server started in background thread on localhost:7011"
puts "Sleeping for 10 to allow announce"
sleep(10)


puts "Starting benchmarks"
Benchmark.bm do |x|

  uri = URI.parse("http://127.0.0.1:7011/")
  ::Net::HTTP.start(uri.host, uri.port) do |hc|
    x.report("vanilla") {
      1_000.times {
        req = Net::HTTP::Get.new(uri.request_uri)
        hc.request(req)
      }
    }
  end

  uri = URI.parse("http://127.0.0.1:7012/")
  ::Net::HTTP.start(uri.host, uri.port) do |hc|
    x.report("traced ") {
      1_000.times {
        ::Instana.tracer.start_or_continue_trace(:rack_call) do
          req = Net::HTTP::Get.new(uri.request_uri)
          hc.request(req)
        end
      }
    }
  end
end


sleep 10
