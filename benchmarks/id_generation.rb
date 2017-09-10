#!/usr/bin/env ruby
require "bundler"
Bundler.require(:default)

require "benchmark"

ID_RANGE = -2**63..2**63-1

Benchmark.bm do |x|
  x.report("generate_id raw    ")   { 1_000_000.times { rand(-2**63..2**63-1) } }
  x.report("with fixed range   ")   { 1_000_000.times { rand(ID_RANGE) } }
end
