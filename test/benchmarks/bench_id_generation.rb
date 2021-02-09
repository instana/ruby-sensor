# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2017

require 'test_helper'

class BenchIDs < Minitest::Benchmark
  def bench_generate_id
    # TODO: This performs poorly on JRuby.
    assert_performance_constant do |input|
      500_000.times do
        ::Instana::Util.generate_id
      end
    end
  end
end
