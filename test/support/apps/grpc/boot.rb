# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2017

require_relative 'grpc_server'

::Instana.logger.info "Booting instrumented gRPC server on port 50051 for tests."

grpc_server = GRPC::RpcServer.new
Thread.new do
  grpc_server.add_http2_port('127.0.0.1:50051', :this_port_is_insecure)
  grpc_server.handle(PingPongServer)
  grpc_server.run_till_terminated
end

Minitest.after_run do
  ::Instana.logger.info "Killing gRPC server"
  grpc_server.stop
  sleep 2
end

sleep 2
