
require 'logger'
require "instana/version"
require "instana/util"

module Instana
  class << self
    attr_accessor :agent
    attr_accessor :collectors
    attr_accessor :config
    attr_accessor :logger
  end
end

require "instana/config"
require "instana/agent"

Instana.agent = Instana::Agent.new
Instana.collectors = []
Instana.logger = Logger.new(STDOUT)
Instana.logger.info "Stan is on the scene.  Starting Instana instrumentation."

if Instana.agent.host_agent_ready?
  Instana.agent.announce_sensor
  require "instana/collectors"
else
  Instana.logger.debug "Instana host agent not available.  Going to sit in a corner quietly."
end
