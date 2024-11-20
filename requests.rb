# (c) Copyright IBM Corp. 2024
# (c) Copyright Instana Inc. 2024

require 'uri'
require 'net/http'
require 'openssl'
require 'concurrent-ruby'
class Hello
  include Concurrent::Async

  def hello(name)
    "Hello, #{name}!"
  end

  def caller
    Instana::Tracer.trace(:multi_get_block) do
      uri = URI.parse('https://goodle.com')
      puts "url: '#{uri}'"

      http = Net::HTTP.new(uri.host, uri.port)
      http.ssl_timeout = 5
      if uri.scheme.to_s.downcase == 'https'
        puts 'HTTPS request'
        http.use_ssl = true
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      end
      request = Net::HTTP::Get.new(uri)
      response = http.request(request)

      puts "response code: #{response.code}"
      if response.code.to_i == 200
        puts 'response OK'
      else
        puts 'response FAILED'
      end
    end
  end
end

hh = Hello.new
Instana::Tracer.start_or_continue_trace(:sample_async_block) do
  10.times do
    hh.async.caller
  end
end
