require 'test_helper'

class TraceTest < Minitest::Test
  def test_trace_spans_count
    t = ::Instana::Trace.new(:test_trace, { :one => 1, :two => 2 })
    t.new_span(:sub_span, { :sub_four => 4 })
    t.end_span(:sub_five => 5)
    t.end_span(:three => 3)
    assert t.spans.size == 2
  end

end
