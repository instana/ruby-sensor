
require 'logger'
require "instana/version"
require "instana/util"

module Instana
  class << self
    attr_accessor :agent
    attr_accessor :collectors
    attr_accessor :config
    attr_accessor :logger
    attr_accessor :pid

    ##
    # start
    #
    # Initialize the Instana language agent
    #
    def start
      Instana.agent = Instana::Agent.new
      Instana.collectors = []
      Instana.logger = Logger.new(STDOUT)
      Instana.logger.info "Stan is on the scene.  Starting Instana instrumentation."

      # Store the current pid so we can detect a potential fork
      # later on
      Instana.pid = Process.pid
    end

    def pid_change?
      @pid != Process.pid
    end
  end
end

require "instana/config"
require "instana/agent"

::Instana.start

if ::Instana.agent.host_agent_ready?
  ::Instana.agent.announce_sensor
  require "instana/collectors"
else
  ::Instana.logger.info "Instana host agent not available.  Going to sit in a corner quietly."
end
