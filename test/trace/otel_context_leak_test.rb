# (c) Copyright IBM Corp. 2026

require 'test_helper'
require 'rack/mock_request'

# Regression tests for the OTel context-stack corruption bugs where certain
# instrumentation paths left a non-SpanContext object as the `context` of a
# non-recording span, causing `NoMethodError` on the next `start_span` call.
#
# Each scenario maps directly to a root-cause analysis documented in the
# companion file `test_app_scenarios.rb`.
class OtelContextLeakTest < Minitest::Test
  # -----------------------------------------------------------------------
  # Setup / Teardown
  # -----------------------------------------------------------------------

  def setup
    @rack_app     = Rack::Builder.new do
      use Instana::Rack
      run ->(_env) { [200, { 'content-type' => 'text/plain' }, ['ok']] }
    end
    @mock_request = Rack::MockRequest.new(@rack_app)
  end

  def teardown
    # Reset the OTel context stack to ROOT unconditionally. attach+detach is
    # a no-op here because detach restores the *previous* value (the leaked
    # frame), not ROOT. Context.clear resets the thread-local directly.
    OpenTelemetry::Context.clear

    ::Instana.tracer.clear!
    Instana.agent.define_singleton_method(:ready?) { true }
    ::Instana.config[:allow_exit_as_root] = false
    clear_all!
  end

  # -----------------------------------------------------------------------
  # Shared helpers
  # -----------------------------------------------------------------------

  # Builds and attaches the corrupted OTel context frame that the unpatched
  # Rack middleware would leave behind — a non_recording_span whose `.context`
  # returns an OpenTelemetry::Context instead of a SpanContext.
  #
  # Yields the attached token; always detaches on exit regardless of outcome.
  def with_corrupted_frame(trace_id: 'abc123', span_id: 'def456')
    span_ctx       = Instana::SpanContext.new(trace_id: trace_id, span_id: span_id)
    nrs            = OpenTelemetry::Trace.non_recording_span(span_ctx)
    corrupted_ctx  = Instana::Trace.context_with_span(nrs)           # OTel Context, not SpanContext
    corrupted_span = OpenTelemetry::Trace.non_recording_span(corrupted_ctx) # .context => OTel Context
    leaked_frame   = OpenTelemetry::Trace.context_with_span(corrupted_span)
    token          = OpenTelemetry::Context.attach(leaked_frame)
    yield token
  ensure
    OpenTelemetry::Context.detach(token)
  end

  # Assert that the span returned by start_span is a live, recording Instana span.
  def assert_recording_span(span, msg = nil)
    assert_instance_of Instana::Span, span, msg || 'Expected an Instana::Span'
    assert span.recording?,               "#{msg || 'Span'} must be recording"
  end

  # -----------------------------------------------------------------------
  # RACK — context-stack detach (agent down + upstream headers)
  #
  # When the agent is down and a request arrives with upstream Instana trace
  # headers, Rack builds a parent_context (an OTel Context), attaches it, and
  # — before the fix — never detached it because the `detach` call was inside
  # the `tracing?` guard.  The poisoned frame survived to the next request,
  # which crashed with NoMethodError in tracer_provider / samplers.
  #
  # Fix: rack.rb ensure block unconditionally calls `Context.detach(@trace_token)`.
  # -----------------------------------------------------------------------

  def test_rack_detaches_context_token_when_agent_is_down
    Instana.agent.define_singleton_method(:ready?) { false }

    res = @mock_request.get(
      '/',
      'HTTP_X_INSTANA_T' => 'abc123',
      'HTTP_X_INSTANA_S' => 'def456',
      'HTTP_X_INSTANA_L' => '1'
    )

    assert_equal 200, res.status
    assert_equal OpenTelemetry::Context::ROOT, OpenTelemetry::Context.current,
                 'Rack must detach its context token even when the agent is down'
  end

  def test_rack_recovers_cleanly_after_upstream_headers_arrive_while_agent_is_down
    Instana.agent.define_singleton_method(:ready?) { false }
    @mock_request.get(
      '/',
      'HTTP_X_INSTANA_T' => 'abc123',
      'HTTP_X_INSTANA_S' => 'def456',
      'HTTP_X_INSTANA_L' => '1'
    )

    Instana.agent.define_singleton_method(:ready?) { true }

    res = @mock_request.get('/')
    assert_equal 200, res.status
    # The context stack must be clean again after a successful traced request.
    assert_equal OpenTelemetry::Context::ROOT, OpenTelemetry::Context.current,
                 'Rack must restore context to ROOT after a normal traced request'
  end

  # -----------------------------------------------------------------------
  # REST-CLIENT — explicit with_parent on poisoned stack
  #
  # rest-client.rb forwards `OpenTelemetry::Context.current` as `with_parent`
  # to `start_span`.  When the thread's context stack holds a corrupted frame,
  # this bypasses the `||=` fallback guard and routes the bad context directly
  # into `internal_start_span`, hitting the crash in samplers.rb.
  #
  # Fix: samplers.rb guards `.tracestate` with `respond_to?`.
  # -----------------------------------------------------------------------

  def test_rest_client_start_span_tolerates_poisoned_otel_context_on_stack
    with_corrupted_frame(trace_id: 'abc123', span_id: 'def456') do
      span = ::Instana.tracer.start_span(:'rest-client', with_parent: OpenTelemetry::Context.current)
      assert_recording_span span, 'rest-client span'
      span.finish
    end
  end

  # -----------------------------------------------------------------------
  # NET-HTTP — implicit Context.current fallback on poisoned stack
  #
  # net-http.rb calls `start_span(:'net-http')` without `with_parent`, so
  # tracer.rb falls back to `OpenTelemetry::Context.current`.
  #
  # When allow_exit_as_root=false (default): `tracing?` returns false when
  # `current_span` is nil, so `skip_instrumentation?` short-circuits and
  # `start_span` is never reached — no crash, span not recorded (expected).
  #
  # When allow_exit_as_root=true: `tracing?` returns true, the guard is
  # bypassed, and `start_span` is called with the poisoned context.
  #
  # Fix: same as REST-CLIENT — samplers.rb guards `.tracestate`.
  # -----------------------------------------------------------------------

  def test_net_http_skips_instrumentation_when_not_tracing_and_exit_as_root_is_off
    with_corrupted_frame(trace_id: 'aaa111', span_id: 'bbb222') do
      # Reproduce the skip_instrumentation? logic from net-http.rb line 70-73.
      # `started?` is an instance method of Net::HTTP and is not testable here
      # without a live connection, so we omit it — it is not relevant to the
      # poisoned-context path being exercised.
      dnt_spans = %i[dynamodb sqs sns s3]
      skip = !Instana.tracer.tracing? ||
             !Instana.config[:nethttp][:enabled] ||
             (!::Instana.tracer.current_span.nil? &&
               dnt_spans.include?(::Instana.tracer.current_span.name))

      assert skip, 'net-http must skip instrumentation when tracing? is false'
      refute Instana.tracer.tracing?,
             'tracing? must be false when current_span is nil and allow_exit_as_root is off'
    end
  end

  def test_net_http_start_span_tolerates_poisoned_otel_context_when_exit_as_root_is_on
    ::Instana.config[:allow_exit_as_root] = true

    with_corrupted_frame(trace_id: 'aaa111', span_id: 'bbb222') do
      assert Instana.tracer.tracing?, 'tracing? must be true when allow_exit_as_root is on'

      span = ::Instana.tracer.start_span(:'net-http')
      assert_recording_span span, 'net-http span'
      span.finish
    end
  end

  # -----------------------------------------------------------------------
  # GRPC — corrupted parent_context passed directly as with_parent
  #
  # grpc.rb builds a parent_context via `non_recording_span` +
  # `Trace.context_with_span`, producing an OTel Context (not a SpanContext),
  # then passes it directly as `with_parent: parent_context`.  With the agent
  # up this reaches `internal_start_span` → samplers.rb → crash.
  #
  # Fix: same as REST-CLIENT — samplers.rb guards `.tracestate`.
  # -----------------------------------------------------------------------

  def test_grpc_start_span_tolerates_context_wrapping_otel_context_as_parent
    # Replicate exactly what GRPCServerInstrumentation#handle_* does when
    # upstream Instana headers are present.
    incoming_context = Instana::SpanContext.new(
      trace_id: ::Instana::Util.header_to_id('deadbeef'),
      span_id:  ::Instana::Util.header_to_id('cafebabe')
    )
    nrs            = OpenTelemetry::Trace.non_recording_span(incoming_context)
    parent_context = Instana::Trace.context_with_span(nrs) # OTel Context — the corrupted form

    span = ::Instana.tracer.start_span(:'rpc-server', with_parent: parent_context)
    assert_recording_span span, 'rpc-server span'
    span.finish
  end

  # -----------------------------------------------------------------------
  # ACTION CABLE — context stored from Rack-poisoned thread
  #
  # When the WebSocket upgrade request runs on a Rack-poisoned thread (agent
  # was down, upstream headers present), `OpenTelemetry::Context.current`
  # returns the corrupted frame.  ActionCable stores that as `@instana_trace_context`.
  # A later transmit/dispatch_action wraps it in `non_recording_span`, then
  # calls `start_span` via `in_span`, which fires the crash.
  #
  # Fix: rack.rb detach fix ensures the poison is gone before ActionCable ever
  #      reads `Context.current`; samplers.rb fix provides a second line of
  #      defence if any other path produces the same corrupted shape.
  # -----------------------------------------------------------------------

  def test_action_cable_start_span_tolerates_context_stored_from_rack_poisoned_thread
    # Step 1: Rack-poison the thread (agent down + upstream headers).
    Instana.agent.define_singleton_method(:ready?) { false }
    @mock_request.get(
      '/',
      'HTTP_X_INSTANA_T' => 'dead01',
      'HTTP_X_INSTANA_S' => 'beef02',
      'HTTP_X_INSTANA_L' => '1'
    )

    # Step 2: Agent recovers.  ActionCable#process reads Context.current to
    # store the trace context for the WebSocket session.
    Instana.agent.define_singleton_method(:ready?) { true }
    stored_ctx = if ::Instana.tracer.tracing?
                   ::Instana.tracer.current_span.context
                 else
                   OpenTelemetry::Context.current
                 end

    # Step 3: A later transmit/dispatch_action wraps stored_ctx and starts a span.
    nrs_cable = OpenTelemetry::Trace.non_recording_span(stored_ctx)
    Instana::Trace.with_span(nrs_cable) do
      span = ::Instana.tracer.start_span(:'rpc-server')
      assert_recording_span span, 'rpc-server span in ActionCable dispatch'
      span.finish
    end
  end
end
