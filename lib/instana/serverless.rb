# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2021

require 'base64'
require 'zlib'

# :nocov:
begin
  require 'instana/instrumentation/instrumented_request'
rescue LoadError => _e
  Instana.logger.warn("Unable to load Instana::InstrumentedRequest. "\
                      "This is normal when the Rack gem is not installed. "\
                      "HTTP based triggers won't generate spans.")
end
# :nocov:

module Instana
  # @since 1.198.0
  class Serverless
    def initialize(agent: ::Instana.agent, tracer: ::Instana.tracer, logger: ::Instana.logger)
      @agent = agent
      @tracer = tracer
      @logger = logger
    end

    def wrap_aws(event, context, &block)
      Thread.current[:instana_function_arn] = [context.invoked_function_arn, context.function_version].join(':')
      trigger, event_tags, span_context = trigger_from_event(event, context)

      tags = {
        lambda: {
          arn: context.invoked_function_arn,
          functionName: context.function_name,
          functionVersion: context.function_version,
          runtime: 'ruby',
          trigger: trigger
        }
      }

      if event_tags.key?(:http)
        tags = tags.merge(event_tags)
      else
        tags[:lambda] = tags[:lambda].merge(event_tags)
      end
      Trace.with_span(OpenTelemetry::Trace.non_recording_span(::Instana::SpanContext.new(trace_id: span_context[:trace_id],span_id: span_context[:span_id],level: span_context[:level]))) do
        @tracer.in_span(:'aws.lambda.entry', attributes: tags, &block)
      end
    ensure
      begin
        @agent.send_bundle
      rescue StandardError => e
        @logger.error(e.message)
      end
      Thread.current[:instana_function_arn] = nil
    end

    private

    def trigger_from_event(event, context) # rubocop:disable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
      case event
      when ->(e) { defined?(::Instana::InstrumentedRequest) && e.is_a?(Hash) && e.key?('requestContext') && e['requestContext'].key?('elb') }
        request = InstrumentedRequest.new(event_to_rack(event))
        ['aws:application.load.balancer', {http: request.request_tags}, request.incoming_context]
      when ->(e) { defined?(::Instana::InstrumentedRequest) && e.is_a?(Hash) && e.key?('httpMethod') && e.key?('path') && e.key?('headers') }
        request = InstrumentedRequest.new(event_to_rack(event))
        ['aws:api.gateway', {http: request.request_tags}, request.incoming_context]
      when ->(e) { e.is_a?(Hash) && e['source'] == 'aws.events' && e['detail-type'] == 'Scheduled Event' }
        tags = decode_cloudwatch_events(event)
        ['aws:cloudwatch.events', {cw: tags}, {}]
      when ->(e) { e.is_a?(Hash) && e.key?('awslogs') }
        tags = decode_cloudwatch_logs(event)
        ['aws:cloudwatch.logs', {cw: tags}, {}]
      when ->(e) { e.is_a?(Hash) && e.key?('Records') && e['Records'].is_a?(Array) && e['Records'].first && e['Records'].first['source'] == 'aws:s3' }
        tags = decode_s3(event)
        ['aws:s3', {s3: tags}, {}]
      when ->(e) { e.is_a?(Hash) && e.key?('Records') && e['Records'].is_a?(Array) && e['Records'].first && e['Records'].first['source'] == 'aws:sqs' }
        tags = decode_sqs(event)
        ['aws:sqs', {sqs: tags}, {}]
      else
        ctx = context_from_lambda_context(context)
        if ctx.empty?
          ['aws:api.gateway.noproxy', {}, {}]
        else
          ['aws.lambda.invoke', {}, ctx]
        end
      end
    end

    def context_from_lambda_context(context)
      return {} unless context.client_context

      begin
        context = JSON.parse(Base64.decode64(context.client_context))

        {
          trace_id: context['X-INSTANA-T'],
          span_id: context['X-INSTANA-S'],
          level: Integer(context['X-INSTANA-L'])
        }
      rescue TypeError, JSON::ParserError, NoMethodError => _e
        {}
      end
    end

    def event_to_rack(event)
      event['headers']
        .transform_keys { |k| "HTTP_#{k.gsub('-', '_').upcase}" }
        .merge(
          'QUERY_STRING' => URI.encode_www_form(event['queryStringParameters'] || {}),
          'PATH_INFO' => event['path'],
          'REQUEST_METHOD' => event['httpMethod']
        )
    end

    def decode_cloudwatch_events(event)
      {
        events: {
          id: event['id'],
          resources: event['resources']
        }
      }
    end

    def decode_cloudwatch_logs(event)
      logs = begin
        payload = JSON.parse(Zlib::Inflate.inflate(Base64.decode64(event['awslogs']['data'])))

        {
          group: payload['logGroup'],
          stream: payload['logStream']
        }
      rescue StandardError => e
        {
          decodingError: e.message
        }
      end

      {logs: logs}
    end

    def decode_s3(event)
      span_events = event['Records'].map do |record|
        {
          name: record['eventName'],
          bucket: record['s3'] && record['s3']['bucket'] ? record['s3']['bucket']['name'] : nil,
          object: record['s3'] && record['s3']['object'] ? record['s3']['object']['key'] : nil
        }
      end

      {events: span_events}
    end

    def decode_sqs(event)
      span_events = event['Records'].map do |record|
        {
          queue: record['eventSourceARN']
        }
      end

      {messages: span_events}
    end
  end
end
