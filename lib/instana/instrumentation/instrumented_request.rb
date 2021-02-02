# Note: We really only need "cgi/util" here but Ruby 2.4.1 has an issue:
# https://bugs.ruby-lang.org/issues/13539
require 'cgi'
require 'rack/request'

module Instana
  class InstrumentedRequest < Rack::Request
    def skip_trace?
      # Honor X-Instana-L
      @env.has_key?('HTTP_X_INSTANA_L') && @env['HTTP_X_INSTANA_L'].start_with?('0')
    end

    def incoming_context
      context = {}

      if @env['HTTP_X_INSTANA_T']
        context[:trace_id] = ::Instana::Util.header_to_id(@env['HTTP_X_INSTANA_T'])
        context[:span_id] = ::Instana::Util.header_to_id(@env['HTTP_X_INSTANA_S']) if @env['HTTP_X_INSTANA_S']
        context[:level] = @env['HTTP_X_INSTANA_L'][0] if @env['HTTP_X_INSTANA_L']
      end

      context
    end

    def extra_header_tags
      return nil unless ::Instana.agent.extra_headers
      headers = {}

      ::Instana.agent.extra_headers.each do |custom_header|
        # Headers are available in this format: HTTP_X_CAPTURE_THIS
        rack_header = 'HTTP_' + custom_header.upcase
        rack_header.tr!('-', '_')

        headers[custom_header.to_sym] = @env[rack_header] if @env.has_key?(rack_header)
      end

      headers
    end

    def request_tags
      {
        method: request_method,
        url: CGI.unescape(path_info),
        host: host_with_port,
        header: extra_header_tags
      }.compact
    end

    def correlation_data
      @correlation_data ||= parse_correlation_data
    end

    private

    def parse_correlation_data
      return {} unless @env.has_key?('HTTP_X_INSTANA_L')
      _level, *tokens = @env['HTTP_X_INSTANA_L'].split(/[,=;]/)
      data = tokens
        .map { |t| t.strip }
        .each_slice(2)
        .select { |a| a.length == 2 }.to_h

      {
        type: data['correlationType'],
        id: data['correlationId']
      }.compact
    end
  end
end
