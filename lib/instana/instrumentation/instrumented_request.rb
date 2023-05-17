# Note: We really only need "cgi/util" here but Ruby 2.4.1 has an issue:
# https://bugs.ruby-lang.org/issues/13539

# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2021

require 'cgi'
require 'rack/request'

module Instana
  class InstrumentedRequest < Rack::Request
    W3C_TRACE_PARENT_FORMAT = /[0-9a-f][0-9a-e]-(?<trace>[0-9a-f]{32})-(?<parent>[0-9a-f]{16})-(?<flags>[0-9a-f]{2})/.freeze
    INSTANA_TRACE_STATE = /in=(?<trace>[0-9a-f]+);(?<span>[0-9a-f]+)/.freeze

    def skip_trace?
      # Honor X-Instana-L
      @env.has_key?('HTTP_X_INSTANA_L') && @env['HTTP_X_INSTANA_L'].start_with?('0')
    end

    def incoming_context
      context = if !correlation_data.empty?
                  {}
                elsif @env['HTTP_X_INSTANA_T']
                  context_from_instana_headers
                elsif @env['HTTP_TRACEPARENT']
                  context_from_trace_parent
                elsif @env['HTTP_TRACESTATE']
                  context_from_trace_state
                else
                  {}
                end

      context[:level] = @env['HTTP_X_INSTANA_L'][0] if @env['HTTP_X_INSTANA_L']

      unless ::Instana.config[:w3c_trace_correlation]
        trace_state = parse_trace_state

        if context[:from_w3c] && trace_state.empty?
          context.delete(:span_id)
          context[:from_w3c] = false
        elsif context[:from_w3c] && !trace_state.empty?
          context[:trace_id] = trace_state[:t]
          context[:span_id] = trace_state[:p]
          context[:from_w3c] = false
        end
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

    def request_params
      ::Instana.secrets.remove_from_query(@env['QUERY_STRING'])
    end

    def request_tags
      {
        method: request_method,
        url: CGI.unescape(path_info),
        host: host_with_port,
        header: extra_header_tags,
        params: request_params
      }.reject { |_, v| v.nil? }
    end

    def correlation_data
      @correlation_data ||= parse_correlation_data
    end

    def instana_ancestor
      @instana_ancestor ||= parse_trace_state
    end

    def continuing_from_trace_parent?
      incoming_context[:from_w3c]
    end

    def synthetic?
      @env.has_key?('HTTP_X_INSTANA_SYNTHETIC') && @env['HTTP_X_INSTANA_SYNTHETIC'].eql?('1')
    end

    def long_instana_id?
      ::Instana::Util.header_to_id(@env['HTTP_X_INSTANA_T']).length == 32
    end

    def external_trace_id?
      continuing_from_trace_parent? || long_instana_id?
    end

    def external_trace_id
      incoming_context[:long_instana_id] || incoming_context[:external_trace_id]
    end

    private

    def context_from_instana_headers
      sanitized_t = ::Instana::Util.header_to_id(@env['HTTP_X_INSTANA_T'])
      sanitized_s = ::Instana::Util.header_to_id(@env['HTTP_X_INSTANA_S'])
      external_trace_id = if @env['HTTP_TRACEPARENT']
                            context_from_trace_parent[:external_trace_id]
                          elsif long_instana_id?
                            sanitized_t
                          end

      {
        span_id: sanitized_s,
        trace_id: long_instana_id? ? sanitized_t[16..-1] : sanitized_t, # rubocop:disable Style/SlicingWithRange, Lint/RedundantCopDisableDirective
        long_instana_id: long_instana_id? ? sanitized_t : nil,
        external_trace_id: external_trace_id,
        external_state: @env['HTTP_TRACESTATE'],
        from_w3c: false
      }.reject { |_, v| v.nil? }
    end

    def context_from_trace_parent
      return {} unless @env.has_key?('HTTP_TRACEPARENT')
      matches = @env['HTTP_TRACEPARENT'].match(W3C_TRACE_PARENT_FORMAT)
      return {} unless matches
      return {} if matches_is_invalid(matches)

      trace_id = ::Instana::Util.header_to_id(matches['trace'][16..-1]) # rubocop:disable Style/SlicingWithRange, Lint/RedundantCopDisableDirective
      span_id = ::Instana::Util.header_to_id(matches['parent'])

      {
        external_trace_id: matches['trace'],
        external_state: @env['HTTP_TRACESTATE'],
        trace_id: trace_id,
        span_id: span_id,
        from_w3c: true
      }
    end

    def matches_is_invalid(matches)
      matches['trace'].match(/\A0+\z/) || matches['parent'].match(/\A0+\z/)
    end

    def context_from_trace_state
      state = parse_trace_state

      {
        trace_id: state[:t],
        span_id: state[:p],
        from_w3c: false
      }.reject { |_, v| v.nil? }
    end

    def parse_trace_state
      return {} unless @env.has_key?('HTTP_TRACESTATE')
      token = @env['HTTP_TRACESTATE']
        .split(/,/)
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
      }.reject { |_, v| v.nil? }
    end
  end
end
