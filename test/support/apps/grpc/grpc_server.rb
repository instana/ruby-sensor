# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2017

require 'google/protobuf'

Google::Protobuf::DescriptorPool.generated_pool.build do
  add_message "PingPongService.PingRequest" do
    optional :message, :string, 1
  end
  add_message "PingPongService.PongReply" do
    optional :message, :string, 1
  end
end

module PingPongService
  PingRequest = Google::Protobuf::DescriptorPool.generated_pool.lookup("PingPongService.PingRequest").msgclass
  PongReply = Google::Protobuf::DescriptorPool.generated_pool.lookup("PingPongService.PongReply").msgclass
end
require 'grpc'

module PingPongService
  # The greeting service definition.
  class Service
    include GRPC::GenericService

    self.marshal_class_method = :encode
    self.unmarshal_class_method = :decode
    self.service_name = 'PingPongService'

    rpc :Ping, PingRequest, PongReply
    rpc :PingWithClientStream, stream(PingRequest), PongReply
    rpc :PingWithServerStream, PingRequest, stream(PongReply)
    rpc :PingWithBidiStream, stream(PingRequest), stream(PongReply)

    rpc :FailToPing, PingRequest, PongReply
    rpc :FailToPingWithClientStream, stream(PingRequest), PongReply
    rpc :FailToPingWithServerStream, PingRequest, stream(PongReply)
    rpc :FailToPingWithBidiStream, stream(PingRequest), stream(PongReply)
  end

  Stub = Service.rpc_stub_class
end

class PingPongServer < PingPongService::Service
  def ping(ping_request, active_call)
    PingPongService::PongReply.new(message: "Hello #{ping_request.message}")
  end

  def ping_with_client_stream(active_call)
    message = ''
    active_call.each_remote_read do |req|
      message += req.message
    end
    PingPongService::PongReply.new(message: message)
  end

  def ping_with_server_stream(ping_request, active_call)
    (0..5).map do |index|
      PingPongService::PongReply.new(message: index.to_s)
    end
  end

  def ping_with_bidi_stream(ping_requests)
    ping_requests.map do |ping_request|
      PingPongService::PongReply.new(message: ping_request.message)
    end
  end

  def fail_to_ping(ping_request, active_call)
    raise 'Unexpected failed'
  end

  def fail_to_ping_with_client_stream(active_call)
    raise 'Unexpected failed'
  end

  def fail_to_ping_with_server_stream(ping_request, active_call)
    raise 'Unexpected failed'
  end

  def fail_to_ping_with_bidi_stream(ping_requests)
    raise 'Unexpected failed'
  end
end
