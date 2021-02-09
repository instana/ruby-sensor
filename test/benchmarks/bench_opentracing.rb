# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2017

require 'test_helper'

class BenchOpenTracing < Minitest::Benchmark
  def bench_start_finish_span
    assert_performance_constant do |input|
      10_000.times do
        span = ::Instana.tracer.start_span(:blah)
        span.set_tag(:zero, 0)
        span.finish
      end
    end
  end
end
