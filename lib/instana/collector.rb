module Instana
  class Collector
    attr_accessor :collectors
    attr_accessor :last_report_log

    def initialize
      @collectors = []

      # Snapshot data is collected once per process but resent
      # every 10 minutes along side process metrics.
      @snapshot = ::Instana::Util.take_snapshot

      # Set last snapshot to just under 10 minutes ago
      # so we send a snapshot sooner than later
      @last_snapshot = Time.now - 570

      # We track what we last sent as a metric payload so that
      # we can do delta reporting
      @last_values = {}
    end

    # Register an individual collector.
    #
    # @param [Object] the class of the collector to register
    #
    def register(klass)
      ::Instana.logger.debug "Adding #{klass} to collectors..."
      @collectors << klass.new
    end

    # Resets the timer on when to send process snapshot data.
    #
    def reset_timer!
      # Set last snapshot to 10 minutes ago
      # so we send a snapshot on first report
      @last_snapshot = Time.now - 601
    end

    ##
    # collect_and_report
    #
    # Run through each collector, let them collect up
    # data and then report what we have via the agent
    #
    # @return Boolean true on success
    #
    def collect_and_report
      return unless ::Instana.config[:metrics][:enabled]

      payload = {}
      with_snapshot = false

      # Run through the registered collectors and
      # get all the metrics
      #
      @collectors.each do |c|
        metrics = c.collect
        if metrics
          payload[c.payload_key] = metrics
        else
          payload.delete(c.payload_key)
        end
      end

      # Every 5 minutes, send snapshot data as well
      if (Time.now - @last_snapshot) > 600
        with_snapshot = true
        payload.merge!(@snapshot)

        # Add in process related that could have changed since
        # snapshot was taken.
        p = { :pid => ::Instana.agent.report_pid }
        p[:name] = ::Instana::Util.get_app_name
        p[:exec_args] = ::Instana.agent.process[:arguments]
        payload.merge!(p)
      else
        payload = enforce_deltas(payload, @last_values)
      end

      if ENV['INSTANA_TEST']
        true
      else
        # Report all the collected goodies
        if ::Instana.agent.report_metrics(payload) && with_snapshot
          @last_snapshot = Time.now
        end
      end
    end

    # Take two hashes and enforce delta reporting.
    # We only report when values change (instead of reporting all of
    # the time).  This is a recursive method.
    #
    # @param [Hash] the payload have delta reporting applied to
    # @param [Hash] a hash of the last values reported
    #
    # @return [Hash] the candidate hash with delta reporting applied
    #
    def enforce_deltas(candidate, last)
      candidate.each do |k,v|
        if v.is_a?(Hash)
          last[k] ||= {}
          candidate[k] = enforce_deltas(candidate[k], last[k])
          candidate.delete(k) if candidate[k].empty?
        else
          if last[k] == v
            candidate.delete(k)
          else
            last[k] = candidate[k]
          end
        end
      end
      candidate
    end
  end
end
