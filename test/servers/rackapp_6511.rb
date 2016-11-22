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
  }

  Rack::Handler::Puma.run(app, {:Host => '127.0.0.1', :Port => 6511})
end

sleep(2)
