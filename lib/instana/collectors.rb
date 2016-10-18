require 'timers'
require 'instana/collectors/heap'
require 'instana/collectors/gc'

module Instana
  module Collector
    class << self
      attr_accessor :interval
    end
  end
end

Instana::Collector.interval = 5
Instana.collectors << Instana::Collector::GC.new
Instana.collectors << Instana::Collector::Heap.new

Thread.new do
  timers = Timers::Group.new
  timers.every(::Instana::Collector.interval) {
    Instana.logger.debug "Collecting..."
    Instana.collectors.each do |c|
      c.collect
    end

    # Report all the collected goodies
    Instana.agent.report_entity_data
  }
  loop { timers.wait }
end
