require "instana/version"
require "instana/agent"
require 'logger'

module Instana
  class << self
    attr_accessor :agent
    attr_accessor :logger
  end
end

Instana.agent = Instana::Agent.new
Instana.logger = Logger.new(STDOUT)
