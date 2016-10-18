
require 'logger'
require "instana/version"
require "instana/agent"
require "instana/util"

module Instana
  class << self
    attr_accessor :agent
    attr_accessor :collectors
    attr_accessor :logger
  end
end

Instana.agent = Instana::Agent.new
Instana.collectors = []
Instana.logger = Logger.new(STDOUT)
Instana.logger.info "Stan is on the scene.  Starting Instana instrumentation."
Instana.agent.announce_sensor

require "instana/collectors"
