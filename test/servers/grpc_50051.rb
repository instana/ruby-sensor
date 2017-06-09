require File.expand_path(File.dirname(__FILE__) + '/../apps/grpc_server.rb')

::Instana.logger.info "Booting instrumented gRPC server on port 50051 for tests."

Thread.new do
  s = GRPC::RpcServer.new
  s.add_http2_port('127.0.0.1:50051', :this_port_is_insecure)
  s.handle(PingPongServer)
  s.run_till_terminated
end

sleep(2)
