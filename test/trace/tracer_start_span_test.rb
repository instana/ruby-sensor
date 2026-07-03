# (c) Copyright IBM Corp. 2026

require 'test_helper'

class TracerStartSpanTest < Minitest::Test
  # While the agent is starting up (or tracing is disabled), start_span
  # returns a non-recording placeholder span whose #context the next span
  # start in the request reads back as its parent.

  # A request arriving with upstream trace headers during agent warmup keeps
  # the upstream ids, so spans recorded later join the upstream trace.
  def test_start_span_when_agent_not_ready_preserves_the_incoming_span_context
    incoming = Instana::Trace::SpanContext.new(trace_id: 'a' * 32, span_id: 'b' * 16)
    with_parent = OpenTelemetry::Trace.context_with_span(
      Instana::Trace.non_recording_span(incoming),
      parent_context: OpenTelemetry::Context.empty
    )

    span = ::Instana.agent.stub(:ready?, false) do
      ::Instana.tracer.start_span(:rack, with_parent: with_parent)
    end

    refute_kind_of OpenTelemetry::Context, span.context
    assert_equal incoming.trace_id, span.context.trace_id
    assert_equal incoming.span_id, span.context.span_id
    assert_equal incoming.tracestate, span.context.tracestate
  end

  # A library call that starts a span without naming a parent inherits the
  # trace already active on the thread.
  def test_start_span_when_agent_not_ready_defaults_to_the_current_context
    ambient = Instana::Trace::SpanContext.new(trace_id: 'c' * 32, span_id: 'd' * 16)
    context = OpenTelemetry::Trace.context_with_span(
      Instana::Trace.non_recording_span(ambient),
      parent_context: OpenTelemetry::Context.empty
    )

    span = OpenTelemetry::Context.with_current(context) do
      ::Instana.agent.stub(:ready?, false) do
        ::Instana.tracer.start_span(:rack)
      end
    end

    assert_equal ambient.trace_id, span.context.trace_id
    assert_equal ambient.span_id, span.context.span_id
  end

  # With no incoming trace and none active on the thread, the placeholder
  # reports an invalid context, since a fabricated valid trace id would
  # become the parent of real spans once the agent comes online, breaking
  # those traces.
  def test_start_span_when_agent_not_ready_and_no_parent_returns_an_invalid_span_context
    span = OpenTelemetry::Context.with_current(OpenTelemetry::Context.empty) do
      ::Instana.agent.stub(:ready?, false) do
        ::Instana.tracer.start_span(:rack)
      end
    end

    refute span.context.valid?
  end
end
