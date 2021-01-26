# Note: We really only need "cgi/util" here but Ruby 2.4.1 has an issue:
# https://bugs.ruby-lang.org/issues/13539

# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2021

require 'cgi'
require 'rack/request'

module Instana
  class InstrumentedRequest < Rack::Request
    W3_TRACE_PARENT_FORMAT = /00-(?<trace>[0-9a-f]+)-(?<parent>[0-9a-f]+)-(?<flags>[0-9a-f]+)/
    INSTANA_TRACE_STATE = /in=(?<trace>[0-9a-f]+);(?<span>[0-9a-f]+)/

    def skip_trace?
      # Honor X-Instana-L
      @env.has_key?('HTTP_X_INSTANA_L') && @env['HTTP_X_INSTANA_L'].start_with?('0')
    end

    def incoming_context
      context = if @env['HTTP_X_INSTANA_T']
                  context_from_instana_headers
                else @env['HTTP_TRACEPARENT'] && ::Instana.config[:w3_trace_correlation]
                  context_from_trace_parent
                end

      context[:level] = @env['HTTP_X_INSTANA_L'][0] if @env['HTTP_X_INSTANA_L']

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

    def instana_ancestor
      @instana_ancestor ||= parse_trace_state
    end

    private

    def context_from_instana_headers
      {
        trace_id: ::Instana::Util.header_to_id(@env['HTTP_X_INSTANA_T']),
        span_id: ::Instana::Util.header_to_id(@env['HTTP_X_INSTANA_S'])
      }.compact
    end

    def context_from_trace_parent
      return {} unless @env.has_key?('HTTP_TRACEPARENT')
      matches = @env['HTTP_TRACEPARENT'].match(W3_TRACE_PARENT_FORMAT)
      return {} unless matches

      {
        external_trace_id: matches['trace'],
        external_state: @env['HTTP_TRACESTATE'],
        trace_id: ::Instana::Util.header_to_id(matches['trace'][16..-1]),
        span_id: ::Instana::Util.header_to_id(matches['parent'])
      }
    end

    def parse_trace_state
      return {} unless @env.has_key?('HTTP_TRACESTATE')
      token = @env['HTTP_TRACESTATE']
        .split(/[,]/)
        .map { |t| t.match(INSTANA_TRACE_STATE) }
        .reject { |t| t.nil? }
        .first
      return {} unless token

      {
        t: token['trace'],
        p: token['span']
      }
    end

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
