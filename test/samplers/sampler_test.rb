# (c) Copyright IBM Corp. 2026

require 'test_helper'
require 'instana/samplers/samplers'

class SamplerTest < Minitest::Test
  # A malformed parent (non_recording_span accepts any object, so a bare
  # Context or Hash can surface here) does not crash span creation and still
  # yields a real Tracestate, which is copied into the new span's context.
  def test_should_sample_tolerates_parents_without_a_real_span_context
    [OpenTelemetry::Context.empty, {}].each do |not_a_span_context|
      poisoned_span = Instana::Trace.non_recording_span(not_a_span_context)
      parent_context = OpenTelemetry::Trace.context_with_span(
        poisoned_span, parent_context: OpenTelemetry::Context.empty
      )

      result = Instana::Trace::Samplers.should_sample?(
        trace_id: 'trace-id', parent_context: parent_context,
        links: nil, name: 'rack', kind: :server, attributes: nil
      )

      assert result.recording?
      assert_instance_of OpenTelemetry::Trace::Tracestate, result.tracestate
    end
  end

  # W3C tracestate received from upstream propagates to child spans
  # unchanged. The parent's tracestate differs from the shared default, so a
  # substituted default fails the assertion.
  def test_should_sample_propagates_the_parent_tracestate
    tracestate = OpenTelemetry::Trace::Tracestate.from_string('in=abc;def')
    parent_span_context = Instana::Trace::SpanContext.new(
      trace_id: 'a' * 32, span_id: 'b' * 16, tracestate: tracestate
    )
    parent_context = OpenTelemetry::Trace.context_with_span(
      Instana::Trace.non_recording_span(parent_span_context),
      parent_context: OpenTelemetry::Context.empty
    )

    result = Instana::Trace::Samplers.should_sample?(
      trace_id: 'trace-id', parent_context: parent_context,
      links: nil, name: 'rack', kind: :server, attributes: nil
    )

    assert result.recording?
    assert_equal 'abc;def', result.tracestate.value('in')
  end
end
