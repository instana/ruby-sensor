require 'timers'
require 'instana/collectors/gc'
require 'instana/collectors/memory'
require 'instana/collectors/thread'

module Instana
  module Collector
    class << self
      attr_accessor :interval
    end
  end
end

if ENV.key?('INSTANA_GEM_DEV')
  ::Instana::Collector.interval = 3
else
  ::Instana::Collector.interval = 1
end

::Thread.new do
  timers = ::Timers::Group.new
  payload = {}

  timers.every(::Instana::Collector.interval) {

    # Check if we forked (unicorn, puma) and
    # if so, re-announce the process sensor
    if ::Instana.pid_change?
      ::Instana.logger.debug "Detected a fork (old: #{::Instana.pid} new: #{::Process.pid}).  Re-announcing sensor."
      ::Instana.pid = Process.pid
      Instana.agent.announce_sensor
    end

    ::Instana.collectors.each do |c|
      metrics = c.collect
      if metrics
        payload[c.payload_key] = metrics
      else
        payload.delete(c.payload_key)
      end
    end

    # Report all the collected goodies
    ::Instana.agent.report_entity_data(payload)
  }
  loop { timers.wait }
end
