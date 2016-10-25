require 'timers'
require 'instana/collectors/gc'
require 'instana/collectors/heap'
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
  ::Instana::Collector.interval = 5
else
  ::Instana::Collector.interval = 1
end

::Thread.new do
  timers = ::Timers::Group.new
  timers.every(::Instana::Collector.interval) {
    ::Instana.collectors.each do |c|
      c.collect
    end

    # Report all the collected goodies
    ::Instana.agent.report_entity_data
  }
  loop { timers.wait }
end
