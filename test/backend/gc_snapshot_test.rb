# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2021

require 'test_helper'

class GcSnapshotTest < Minitest::Test
  def test_report_returns_hash
    subject = Instana::Backend::GCSnapshot.instance
    assert subject.report(1).is_a?(Hash)
  end

  def test_report_contains_expected_keys
    subject = Instana::Backend::GCSnapshot.instance
    result = subject.report(1)
    assert result.key?(:totalTime)
    assert result.key?(:heap_live)
    assert result.key?(:heap_free)
    assert result.key?(:minorGcs)
    assert result.key?(:majorGcs)
  end

  def test_report_normalizes_gc_counts_by_poll_rate
    # Force some GC activity so minor/major counts may differ; we stub GC.stat to control values
    subject = Instana::Backend::GCSnapshot.instance

    # Reset baseline counts via a first report
    subject.report(1)

    # Stub GC.stat to return predictable delta values relative to the baseline
    fake_stats = {
      heap_live_slots: 100_000,
      heap_free_slots: 20_000,
      minor_gc_count: subject.instance_variable_get(:@last_minor_count) + 10,
      major_gc_count: subject.instance_variable_get(:@last_major_count) + 2
    }

    ::GC.stub(:stat, fake_stats) do
      ::GC::Profiler.stub(:total_time, 0.5) do
        result = subject.report(5)
        assert_in_delta 2.0, result[:minorGcs], 0.001   # 10 / 5.0
        assert_in_delta 0.4, result[:majorGcs], 0.001   # 2 / 5.0
      end
    end
  end

  def test_report_normalizes_total_time_by_poll_rate
    subject = Instana::Backend::GCSnapshot.instance
    subject.report(1) # establish baseline

    fake_stats = {
      heap_live_slots: 50_000,
      heap_free_slots: 10_000,
      minor_gc_count: subject.instance_variable_get(:@last_minor_count),
      major_gc_count: subject.instance_variable_get(:@last_major_count)
    }

    ::GC.stub(:stat, fake_stats) do
      # total_time is in seconds; report multiplies by 1000 then divides by poll_rate
      ::GC::Profiler.stub(:total_time, 1.0) do
        result_poll1 = subject.report(1)
        assert_in_delta 1000.0, result_poll1[:totalTime], 0.001  # 1.0 * 1000 / 1
      end
    end

    ::GC.stub(:stat, fake_stats) do
      ::GC::Profiler.stub(:total_time, 1.0) do
        result_poll5 = subject.report(5)
        assert_in_delta 200.0, result_poll5[:totalTime], 0.001   # 1.0 * 1000 / 5
      end
    end
  end

  def test_report_poll_rate_1_returns_raw_gc_counts
    subject = Instana::Backend::GCSnapshot.instance
    subject.report(1) # establish baseline

    fake_stats = {
      heap_live_slots: 80_000,
      heap_free_slots: 15_000,
      minor_gc_count: subject.instance_variable_get(:@last_minor_count) + 3,
      major_gc_count: subject.instance_variable_get(:@last_major_count) + 1
    }

    ::GC.stub(:stat, fake_stats) do
      ::GC::Profiler.stub(:total_time, 0.0) do
        result = subject.report(1)
        assert_in_delta 3.0, result[:minorGcs], 0.001  # 3 / 1.0
        assert_in_delta 1.0, result[:majorGcs], 0.001  # 1 / 1.0
      end
    end
  end

  def test_report_heap_slots_are_not_normalized
    subject = Instana::Backend::GCSnapshot.instance

    fake_stats = {
      heap_live_slots: 42_000,
      heap_free_slots: 8_000,
      minor_gc_count: subject.instance_variable_get(:@last_minor_count),
      major_gc_count: subject.instance_variable_get(:@last_major_count)
    }

    ::GC.stub(:stat, fake_stats) do
      ::GC::Profiler.stub(:total_time, 0.0) do
        result = subject.report(10)
        assert_equal 42_000, result[:heap_live]
        assert_equal 8_000, result[:heap_free]
      end
    end
  end
end
