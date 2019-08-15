# require 'test_helper'
#
# class TraceTest < Minitest::Test
#   def test_trace_spans_count
#     t = ::Instana::Trace.new(:test_trace, { :one => 1, :two => 2 })
#     t.new_span(:sub_span, { :sub_four => 4 })
#     t.end_span(:sub_five => 5)
#     t.end_span(:three => 3)
#     assert t.spans.size == 2
#   end
#
#   def test_trace_with_incoming_context
#     incoming_context = { :trace_id => "1234", :span_id => "4321" }
#     t = ::Instana::Trace.new(:test_trace, { :one => 1, :two => 2 }, incoming_context)
#     first_span = t.spans.first
#     assert_equal "1234", first_span[:t]
#     assert_equal "4321", first_span[:p]
#     assert t.spans.size == 1
#   end
#
#   def test_max_value_of_generated_id
#     # Max is the maximum value for a Java signed long
#     max_value = 9223372036854775807
#     1000.times do
#       assert ::Instana::Util.generate_id <= max_value
#     end
#   end
#
#   def test_min_value_of_generated_id
#     # Max is the maximum value for a Java signed long
#     max_value = -9223372036854775808
#     1000.times do
#       assert ::Instana::Util.generate_id >= max_value
#     end
#   end
#
#   def test_entry_span_doesnt_have_stack_by_default
#     t = ::Instana::Trace.new(:rack)
#     first_span = t.spans.first
#     assert !first_span.key?(:stack)
#   end
#
#   def test_entry_span_has_stack_by_config
#     ::Instana.config[:collect_backtraces] = true
#     t = ::Instana::Trace.new(:rack)
#     first_span = t.spans.first
#     assert first_span.key?(:stack)
#     assert_equal 2, first_span[:stack].count
#     ::Instana.config[:collect_backtraces] = false
#   end
#
#   def test_exit_span_doesnt_have_stack_by_default
#     t = ::Instana::Trace.new(:trace_test)
#     t.new_span(:excon)
#     second_span = t.spans.to_a[1]
#     assert !second_span.key?(:stack)
#   end
#
#   def test_exit_span_has_stack_by_config
#     ::Instana.config[:collect_backtraces] = true
#     t = ::Instana::Trace.new(:trace_test)
#     t.new_span(:excon)
#     second_span = t.spans.to_a[1]
#     assert second_span.key?(:stack)
#     ::Instana.config[:collect_backtraces] = false
#   end
# end
