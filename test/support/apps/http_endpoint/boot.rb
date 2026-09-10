# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2016

require 'rack/handler/puma'
require 'rack/builder'
require 'instana/rack'

::Instana.logger.info "Booting instrumented background Rackapp on port 6511 for tests."

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
    # Returns any status code supplied as the last path segment, e.g. /status/401
    map "/status" do
      run Proc.new { |env|
        code = env['PATH_INFO'].split('/').last.to_i
        code = 200 if code < 100 || code > 599
        [code, {"Content-Type" => "application/json"}, ["[\"status\",#{code}]"]]
      }
    end
  }

  Rackup::Handler::Puma.run(app, Host: '127.0.0.1', Port: 6511)
end

sleep(2)
