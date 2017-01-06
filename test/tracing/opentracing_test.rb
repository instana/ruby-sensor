require 'test_helper'
require 'rack/test'
require 'rack/lobster'
require "opentracing"

module Instana
  class OTRack1
    def initialize(app)
      @app = app
    end

    def call(env)
      otrack1_span = OpenTracing.start_span(:otrack1)
      result = @app.call(env)
      otrack1_span.finish
      result
    end
  end

  class OTRack2
    def initialize(app)
      @app = app
    end

    def call(env)
      otrack2_span = OpenTracing.start_span(:otrack2)
      result = @app.call(env)
      otrack2_span.finish
      result
    end
  end
end

OpenTracing.global_tracer = ::Instana.tracer

class OpenTracerTest < Minitest::Test
  include Rack::Test::Methods

  def app
    @app = Rack::Builder.new {
      use Instana::Rack
      use Instana::OTRack1
      use Rack::CommonLogger
      use Rack::ShowExceptions
      use Instana::OTRack2
      map "/mrlobster" do
        run Rack::Lobster.new
      end
    }
  end

  def test_basic_get_with_opentracing
    ::Instana.processor.clear!
    get '/mrlobster'
    assert last_response.ok?

    traces = ::Instana.processor.queued_traces
    assert_equal 1, traces.count

    trace = traces[0]
    assert trace.valid?

    # Span validation
    assert_equal 3, trace.spans.count
    first_span, second_span, third_span = trace.spans.to_a

    assert_equal :rack, first_span.name
    assert first_span.key?(:data)
    assert first_span[:data].key?(:http)
    assert_equal "GET", first_span[:data][:http][:method]
    assert_equal "/mrlobster", first_span[:data][:http][:url]
    assert_equal 200, first_span[:data][:http][:status]
    assert_equal 'example.org', first_span[:data][:http][:host]
    assert_equal :otrack1, second_span.name
    assert second_span.key?(:data)
    assert second_span[:data].key?(:sdk)
    assert second_span[:data][:sdk].key?(:name)
    assert_equal :otrack2, third_span.name
    assert third_span.key?(:data)
    assert third_span[:data].key?(:sdk)
    assert third_span[:data][:sdk].key?(:name)

    # ID Validation
    assert_equal trace.id, first_span[:t]
    assert_equal trace.id, third_span[:t]

    # Linkage
    assert_equal second_span[:s], third_span[:p]
  end

  def test_get_with_inject_extract
    ::Instana.processor.clear!

    trace_id = ::Instana::Util.generate_id
    span_id = ::Instana::Util.generate_id

    header 'X-Instana-T', ::Instana::Util.id_to_header(trace_id)
    header 'X-Instana-S', ::Instana::Util.id_to_header(span_id)

    get '/mrlobster'
    assert last_response.ok?

    traces = ::Instana.processor.queued_traces
    assert_equal 1, traces.count

    trace = traces[0]
    assert trace.valid?

    # Span validation
    assert_equal 3, trace.spans.count
    first_span = trace.spans.to_a.first

    # Make sure context was picked up and continued in the resulting
    # trace
    assert_equal trace_id, trace.id
    assert_equal span_id, first_span[:p]
  end

  def test_start_span_with_tags
    ::Instana.processor.clear!
    otracer = ::Instana.tracer
    span = otracer.start_span('my_app_entry')

    assert span.is_a?(::Instana::Span)
    assert_equal :my_app_entry, otracer.current_trace.current_span.name

    span.set_tag(:tag_integer, 1234)
    span.set_tag(:tag_boolean, true)
    span.set_tag(:tag_array, [1,2,3,4])
    span.set_tag(:tag_string, "1234")

    assert_equal 1234, span.tags(:tag_integer)
    assert_equal true, span.tags(:tag_boolean)
    assert_equal [1,2,3,4], span.tags(:tag_array)
    assert_equal "1234", span.tags(:tag_string)
    span.finish
  end

  def test_start_span_with_baggage
    ::Instana.processor.clear!
    otracer = ::Instana.tracer
    assert otracer.respond_to?(:start_span)
    span = otracer.start_span('my_app_entry')
    span.set_baggage_item(:baggage_integer, 1234)
    span.set_baggage_item(:baggage_boolean, false)
    span.set_baggage_item(:baggage_array, [1,2,3,4])
    span.set_baggage_item(:baggage_string, '1234')

    assert_equal 1234, span.get_baggage_item(:baggage_integer)
    assert_equal false, span.get_baggage_item(:baggage_boolean)
    assert_equal [1,2,3,4], span.get_baggage_item(:baggage_array)
    assert_equal "1234", span.get_baggage_item(:baggage_string)
    span.finish
  end

  def test_start_span_with_timestamps
    ::Instana.processor.clear!
    otracer = ::Instana.tracer
    ts_start = Time.now
    span_tags = {:start_tag => 1234, :another_tag => 'tag_value'}
    span = otracer.start_span('my_app_entry', tags: span_tags, start_time: ts_start)
    sleep 0.1
    ts_finish = Time.now
    span.finish(ts_finish)

    ts_start_ms = ::Instana::Util.time_to_ms(ts_start)
    ts_finish_ms = ::Instana::Util.time_to_ms(ts_finish)

    assert_equal ts_start_ms, span[:ts]
    assert_equal (ts_finish_ms - ts_start_ms), span[:d]
  end

  def test_nested_spans_using_child_of
    ::Instana.processor.clear!
    otracer = ::Instana.tracer
    entry_span = otracer.start_span(:rack)
    ac_span = otracer.start_span(:action_controller, child_of: entry_span)
    av_span = otracer.start_span(:action_view, child_of: ac_span)
    sleep 0.1
    av_span.finish
    ac_span.finish
    entry_span.finish

    traces = ::Instana.processor.queued_traces

    assert_equal 1, traces.count

    trace = traces.first
    first_span, second_span, third_span = trace.spans.to_a

    assert_equal 3, trace.spans.count
    assert trace.valid?

    # IDs
    assert_equal trace.id, first_span[:t]
    assert_equal trace.id, second_span[:t]
    assert_equal trace.id, third_span[:t]

    # Linkage
    assert first_span.is_root?
    assert_equal first_span[:s], second_span[:p]
    assert_equal second_span[:s], third_span[:p]
  end

  def test_start_span_with_nested_spans
    ::Instana.processor.clear!
    otracer = ::Instana.tracer
    entry_span = otracer.start_span(:rack)
    ac_span = otracer.start_span(:action_controller)
    av_span = otracer.start_span(:action_view)
    sleep 0.1
    av_span.finish
    ac_span.finish
    entry_span.finish

    traces = ::Instana.processor.queued_traces

    assert_equal 1, traces.count
    trace = traces.first
    assert trace.valid?
    assert_equal 3, trace.spans.count

    first_span, second_span, third_span = trace.spans.to_a

    # IDs
    assert_equal trace.id, first_span[:t]
    assert_equal trace.id, second_span[:t]
    assert_equal trace.id, third_span[:t]

    # Linkage
    assert first_span.is_root?
    assert_equal first_span[:s], second_span[:p]
    assert_equal second_span[:s], third_span[:p]
  end

  def test_nested_spans_with_baggage
    ::Instana.processor.clear!
    otracer = ::Instana.tracer
    entry_span = otracer.start_span(:rack)
    ac_span = otracer.start_span(:action_controller)
    ac_span.set_baggage_item(:my_bag, 1)
    av_span = otracer.start_span(:action_view)
    sleep 0.1
    av_span.finish
    ac_span.finish
    entry_span.finish

    traces = ::Instana.processor.queued_traces

    assert_equal 1, traces.count
    trace = traces.first
    assert trace.valid?
    assert_equal 3, trace.spans.count

    first_span, second_span, third_span = trace.spans.to_a

    # IDs
    assert_equal trace.id, first_span[:t]
    assert_equal trace.id, second_span[:t]
    assert_equal trace.id, third_span[:t]

    # Linkage
    assert first_span.is_root?
    assert_equal first_span[:s], second_span[:p]
    assert_equal second_span[:s], third_span[:p]

    # Every span should have baggage
    assert_equal nil, first_span.get_baggage_item(:my_bag)
    assert_equal 1, second_span.get_baggage_item(:my_bag)
    assert_equal 1, third_span.get_baggage_item(:my_bag)
  end

  def test_context_should_carry_baggage
    ::Instana.processor.clear!
    otracer = ::Instana.tracer

    entry_span = otracer.start_span(:rack)
    entry_span_context = entry_span.context

    ac_span = otracer.start_span(:action_controller)
    ac_span.set_baggage_item(:my_bag, 1)
    ac_span_context = ac_span.context

    av_span = otracer.start_span(:action_view)
    av_span_context = av_span.context

    sleep 0.1
    av_span.finish
    ac_span.finish
    entry_span.finish

    traces = ::Instana.processor.queued_traces

    assert_equal 1, traces.count
    trace = traces.first
    assert trace.valid?
    assert_equal 3, trace.spans.count

    assert_equal nil, entry_span_context.baggage[:my_bag]
    assert_equal 1, ac_span_context.baggage[:my_bag]
    assert_equal 1, av_span_context.baggage[:my_bag]
  end

  def test_baggage_with_complex_data
    ::Instana.processor.clear!
    otracer = ::Instana.tracer

    entry_span = otracer.start_span(:rack)
    entry_span_context = entry_span.context

    ac_span = otracer.start_span(:action_controller)

    ac_span.set_baggage_item(:integer, 1)
    ac_span.set_baggage_item(:float, 1.0123948293)
    ac_span.set_baggage_item(:hash, { :hash_sublevel => "blah",
                                      :another => {} })
    ac_span_context = ac_span.context

    av_span = otracer.start_span(:action_view)
    av_span_context = av_span.context

    sleep 0.1
    av_span.finish
    ac_span.finish
    entry_span.finish

    traces = ::Instana.processor.queued_traces

    assert_equal 1, traces.count
    trace = traces.first
    assert trace.valid?
    assert_equal 3, trace.spans.count

    # Context
    assert_equal true, entry_span_context.baggage.empty?
    assert_equal true, entry_span.baggage.empty?

    assert_equal 1, ac_span_context.baggage[:integer]
    assert_equal 1.0123948293, ac_span_context.baggage[:float]
    assert_equal true, ac_span_context.baggage[:hash][:another].empty?
    assert_equal "blah", ac_span_context.baggage[:hash][:hash_sublevel]
    assert_equal 1, av_span_context.baggage[:integer]
    assert_equal 1.0123948293, av_span_context.baggage[:float]
    assert_equal true, av_span_context.baggage[:hash][:another].empty?
    assert_equal "blah", av_span_context.baggage[:hash][:hash_sublevel]

    # Spans
    assert_equal true, entry_span.baggage.empty?
    assert_equal 1, ac_span.baggage[:integer]
    assert_equal 1.0123948293, ac_span.baggage[:float]
    assert_equal true, ac_span.baggage[:hash][:another].empty?
    assert_equal "blah", ac_span.baggage[:hash][:hash_sublevel]
    assert_equal 1, av_span.baggage[:integer]
    assert_equal 1.0123948293, av_span.baggage[:float]
    assert_equal true, av_span.baggage[:hash][:another].empty?
    assert_equal "blah", av_span.baggage[:hash][:hash_sublevel]
  end
end
