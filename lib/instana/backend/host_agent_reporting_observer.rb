# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2021

module Instana
  module Backend
    # Process which is responsible for reporting metrics and tracing to the local agent
    # @since 1.197.0
    class HostAgentReportingObserver
      ENTITY_DATA_URL = '/com.instana.plugin.ruby.%i'.freeze
      RESPONSE_DATA_URL = '/com.instana.plugin.ruby/response.%i?messageId=%s'.freeze
      TRACES_DATA_URL = "/com.instana.plugin.ruby/traces.%i".freeze
      TRACE_METRICS_URL = "/tracermetrics".freeze

      attr_reader :report_timer

      # @param [RequestClient] client used to make requests to the backend
      # @param [Concurrent::Atom] discovery object used to store discovery response in
      def initialize(client, discovery, logger: ::Instana.logger, timer_class: Concurrent::TimerTask, processor: ::Instana.processor)
        @client = client
        @discovery = discovery
        @logger = logger
        @report_timer = timer_class.new(execution_interval: 1, run_now: true) { report_to_backend }
        @nonce = Time.now
        @processor = processor
      end

      def update(time, _old_version, new_version)
        return unless time > @nonce

        @nonce = time
        new_version.nil? ? @report_timer.shutdown : @report_timer.execute
      end

      private

      def report_to_backend
        report_metrics if ::Instana.config[:metrics][:enabled]
        report_traces if ::Instana.config[:tracing][:enabled]
        report_trace_stats if ::Instana.config[:tracing][:enabled]
      rescue StandardError => e
        @logger.error(%(#{e}\n#{e.backtrace.join("\n")}))
      end

      def report_trace_stats
        discovery = @discovery.value
        return unless discovery

        payload = {
          tracer: 'ruby',
          pid: discovery['pid'],
          metrics: @processor.span_metrics
        }

        @client.send_request('POST', TRACE_METRICS_URL, payload)
      end

      def report_traces
        discovery = @discovery.value
        return unless discovery

        path = format(TRACES_DATA_URL, discovery['pid'])

        @processor.send do |spans|
          response = @client.send_request('POST', path, spans)

          unless response.ok?
            @logger.debug("Sent `#{spans.count}` spans to `#{path}` and got `#{response.code}`.")
            @discovery.swap { nil }
            break
          end
        end
      end

      def report_metrics
        discovery = @discovery.value
        return unless discovery

        path = format(ENTITY_DATA_URL, discovery['pid'])
        payload = metrics_payload(discovery).merge(Util.take_snapshot)
        response = @client.send_request('POST', path, payload)

        if response.ok?
          handle_agent_tasks(response, discovery) unless response.body.empty?
        else
          @logger.debug("Sent `#{payload}` to `#{path}` and got `#{response.code}`.")
          @discovery.swap { nil }
        end
      end

      def handle_agent_tasks(response, discovery)
        payload = response.json
        payload = [payload] if payload.is_a?(Hash)
        payload
          .select { |t| t['action'] == 'ruby.source' }
          .each do |action|
            payload = ::Instana::Util.get_rb_source(action['args']['file'])
            path = format(RESPONSE_DATA_URL, discovery['pid'], action['messageId'])
            @client.send_request('POST', path, payload)
          end
      rescue StandardError => e
        @logger.debug("Error processing agent task #{e.inspect}")
      end

      def metrics_payload(discovery)
        payload = {
          pid: discovery['pid'],
          name: Util.get_app_name
        }

        if ::Instana.config[:metrics][:memory][:enabled]
          proc_table = Sys::ProcTable.ps(pid: Process.pid)
          process = ProcessInfo.new(proc_table)
          payload[:exec_args] = process.arguments
          payload[:memory] = {rss_size: process.memory_used / 1024} # Bytes to Kilobytes like in ruby_process.rb

        end

        if ::Instana.config[:metrics][:gc][:enabled]
          payload[:gc] = GCSnapshot.instance.report
        end

        if ::Instana.config[:metrics][:thread][:enabled]
          payload[:thread] = {count: ::Thread.list.count}
        end

        payload
      end
    end
  end
end
