# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2016

module Instana
  class Config
    def initialize(logger: ::Instana.logger, agent_host: ENV['INSTANA_AGENT_HOST'], agent_port: ENV['INSTANA_AGENT_PORT'])
      @config = {}
      if agent_host
        logger.debug "Using custom agent host location specified in INSTANA_AGENT_HOST (#{ENV['INSTANA_AGENT_HOST']})"
        @config[:agent_host] = agent_host
      else
        @config[:agent_host] = '127.0.0.1'
      end
      if agent_port
        logger.debug "Using custom agent port specified in INSTANA_AGENT_PORT (#{ENV['INSTANA_AGENT_PORT']})"
        @config[:agent_port] = agent_port
      else
        @config[:agent_port] = 42699
      end

      # Enable/disable metrics globally or individually (default: all enabled)
      @config[:metrics] = { :enabled => true }
      @config[:metrics][:gc]     = { :enabled => true }
      @config[:metrics][:memory] = { :enabled => true }
      @config[:metrics][:thread] = { :enabled => true }

      # Enable/disable tracing (default: enabled)
      @config[:tracing] = { :enabled => true }

      # Enable/disable tracing exit spans as root spans
      @config[:allow_exit_as_root] = ENV['INSTANA_ALLOW_EXIT_AS_ROOT'] == '1'

      # Enable/Disable logging
      @config[:logging] = { :enabled => true }

      # Collector interval
      @config[:collector] = { :enabled => true, :interval => 1 }

      # EUM Related
      @config[:eum_api_key] = nil
      @config[:eum_baggage] = {}

      # In Ruby, backtrace collection is very expensive so it's
      # (unfortunately) disabled by default.  If you still want
      # backtraces, it can be enabled with this config option.
      # @config[:back_trace][:stack_trace_level] = all
      # @config[:back_trace] = { stack_trace_level: nil }
      read_span_stack_config_from_env

      # By default, collected SQL will be sanitized to remove potentially sensitive bind params such as:
      #   > SELECT  "blocks".* FROM "blocks"  WHERE "blocks"."name" = "Mr. Smith"
      #
      # ...would be sanitized to be:
      #   > SELECT  "blocks".* FROM "blocks"  WHERE "blocks"."name" = ?
      #
      # This sanitization step can be disabled by setting the following value to false.
      # ::Instana.config[:sanitize_sql] = false
      @config[:sanitize_sql] = true

      # W3C Trace Context Support
      @config[:w3c_trace_correlation] = ENV['INSTANA_DISABLE_W3C_TRACE_CORRELATION'].nil?

      @config[:post_fork_proc] = proc { ::Instana.agent.spawn_background_thread }

      @config[:action_controller]  = { :enabled => true }
      @config[:action_view]        = { :enabled => true }
      @config[:active_record]      = { :enabled => true }
      @config[:bunny]              = { :enabled => true }
      @config[:dalli]              = { :enabled => true }
      @config[:excon]              = { :enabled => true }
      @config[:grpc]               = { :enabled => true }
      @config[:graphql]            = { :enabled => true }
      @config[:nethttp]            = { :enabled => true }
      @config[:redis]              = { :enabled => true }
      @config[:'resque-client']    = { :enabled => true, :propagate => true }
      @config[:'resque-worker']    = { :enabled => true, :'setup-fork' => true }
      @config[:'rest-client']      = { :enabled => true }
      @config[:sequel]             = { :enabled => true }
      @config[:'sidekiq-client']   = { :enabled => true }
      @config[:'sidekiq-worker']   = { :enabled => true }
    end

    def [](key)
      @config[key.to_sym]
    end

    def []=(key, value)
      @config[key.to_sym] = value
    end

    def read_span_stack_config_from_env
      stack_trace = ENV['INSTANA_STACK_TRACE']
      stack_trace_length = ENV['INSTANA_STACK_TRACE_LENGTH']

      @config[:back_trace] = {
        stack_trace_level: stack_trace || "error",
        stack_trace_length: stack_trace_length ? stack_trace_length.to_i : 30
      }
    end
  end
end

::Instana.config = ::Instana::Config.new
