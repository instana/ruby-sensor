require_relative 'grpc_server'

::Instana.logger.info "Booting instrumented gRPC server on port 50051 for tests."

grpc_thread = Thread.new do
  s = GRPC::RpcServer.new
  Thread.current[:server] = s

  s.add_http2_port('127.0.0.1:50051', :this_port_is_insecure)
  s.handle(PingPongServer)
  s.run_till_terminated
end

Minitest.after_run do
  ::Instana.logger.info "Killing gRPC server"
  grpc_thread[:server].stop
  sleep 2
end

sleep 2
