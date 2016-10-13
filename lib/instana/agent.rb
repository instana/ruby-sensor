require 'net/http'
require 'uri'
require 'json'

module Instana
  class Agent
    def initiialize
      @request_timeout = 5000
      @host = '127.0.0.1'
      @port = 42699
      @server_header = 'Instana Agent'
      @agentuuid = nil
    end

    def announce_sensor
      uri = URI.parse("http://#{@host}:#{@port}/com.instana.plugin.ruby.discovery")
      payload = {}
      payload[:pid] = Process.pid
      payload[:name] = $0

      req = Net::HTTP::Put.new(uri)
      req['Accept'] = 'application/json'
      req['Content-Type'] = 'application/json'
      req.body = payload.to_json

      response = nil
      Net::HTTP.start(uri.hostname, uri.port) do |http|
        response = http.request(req)
      end
      puts response
    end
  end
end
