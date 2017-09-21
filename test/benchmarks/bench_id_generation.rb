require 'test_helper'

class BenchIDs < Minitest::Benchmark
  def bench_generate_id
    assert_performance_constant do |input|
      500_000.times do
        ::Instana::Util.generate_id
      end
    end
  end
end
