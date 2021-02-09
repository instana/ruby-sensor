# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2017

require "bundler"

require 'rack'
require 'rack/builder'
require 'rack/handler/puma'
require 'net/http'
require "cgi"
Bundler.require(:default)
require "instana/rack"
require 'ruby-prof'

Thread.new do
  app = Rack::Builder.new {
    map "/" do
      run Proc.new {
        [200, {"Content-Type" => "application/json"}, ["[\"Stan\",\"is\",\"on\",\"the\",\"scene!\"]"]]
      }
    end
    map "/error" do
      run Proc.new {
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
      run Proc.new {
        [200, {"Content-Type" => "application/json"}, ["[\"Stan\",\"is\",\"on\",\"the\",\"scene!\"]"]]
      }
    end
    map "/error" do
      run Proc.new {
        [500, {"Content-Type" => "application/json"}, ["[\"Stan\",\"is\",\"on\",\"the\",\"error!\"]"]]
      }
    end
  }

  Rack::Handler::Puma.run(app, {:Host => '127.0.0.1', :Port => 7012})
end

puts ""
puts "Vanilla Rack server started in background thread on localhost:7011"
puts "Instrumented Rack server started in background thread on localhost:7012"
puts ""
puts "Waiting on successful announce to host agent..."
puts ""

#RubyProf.measure_mode = RubyProf::WALL_TIME
#RubyProf.measure_mode = RubyProf::PROCESS_TIME
RubyProf.measure_mode = RubyProf::ALLOCATIONS
#RubyProf.measure_mode = RubyProf::MEMORY

while !::Instana.agent.ready? do
  sleep 2
end

puts "Starting 10k Traces..."

# uri = URI.parse("http://127.0.0.1:7011/")
# ::Net::HTTP.start(uri.host, uri.port) do |hc|
#   x.report("vanilla") {
#     10_000.times {
#       req = Net::HTTP::Get.new(uri.request_uri)
#       hc.request(req)
#     }
#   }
# end

uri = URI.parse("http://127.0.0.1:7012/")
result = RubyProf.profile do
  1.times {
    ::Instana.tracer.start_or_continue_trace(:job, {:kind => :entry}) do
      ::Net::HTTP.start(uri.host, uri.port) do |hc|
        ::Instana.tracer.start_or_continue_trace(:rack_call) do
          req = Net::HTTP::Get.new(uri.request_uri)
          hc.request(req)
        end
      end
    end
  }
end

puts "Done - displaying results..."

printer = RubyProf::FlatPrinter.new(result)
printer.print(STDOUT, {})