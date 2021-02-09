#!/usr/bin/env ruby

# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2017

require "bundler"
Bundler.require(:default)

require "benchmark"

# Process.clock_gettime(Process::CLOCK_MONOTONIC, :millisecond)

Benchmark.bm do |x|
  x.report("Time.now:     ") { 1_000_000.times { (Time.now.to_f * 1000).floor } }
  x.report("get_clocktime:") { 1_000_000.times { Process.clock_gettime(Process::CLOCK_REALTIME, :millisecond) } }
end
