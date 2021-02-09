#!/usr/bin/env ruby

# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2017

require "bundler"
Bundler.require(:default)

require "benchmark"

Benchmark.bm do |x|
  x.report("start_span, finish:             ") {
    50_000.times {
      ::Instana.tracer.start_span(:blah).finish
    }
  }

  x.report("start_span, set_tag(5x), finish:") {
    50_000.times {
      span = ::Instana.tracer.start_span(:blah)
      span.set_tag(:blah, 1)
      span.set_tag(:dog, 1)
      span.set_tag(:moon, "ok")
      span.set_tag(:ape, 1)
      span.set_tag(:blah, 1)
      span.finish
    }
  }

end
