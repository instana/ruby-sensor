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

  def test_supplies_all_ot_interfaces
    clear_all!
    assert defined?(OpenTracing)
    assert OpenTracing.respond_to?(:global_tracer)
    assert OpenTracing.global_tracer.respond_to?(:start_span)
    assert OpenTracing.global_tracer.respond_to?(:inject)
    assert OpenTracing.global_tracer.respond_to?(:extract)

    assert defined?(OpenTracing::Carrier)
    carrier = OpenTracing::Carrier.new
    assert carrier.respond_to?(:[])
    assert carrier.respond_to?(:[]=)
    assert carrier.respond_to?(:each)

    span = OpenTracing.start_span(:blah)
    assert span.respond_to?(:finish)
    assert span.respond_to?(:set_tag)
    assert span.respond_to?(:tags)
    assert span.respond_to?(:operation_name=)
    assert span.respond_to?(:set_baggage_item)
    assert span.respond_to?(:get_baggage_item)
    assert span.respond_to?(:context)
    assert span.respond_to?(:log)
  end

  def test_basic_get_with_opentracing
    clear_all!
    get '/mrlobster'
    assert last_response.ok?

    traces = ::Instana.processor.queued_traces
    assert_equal 1, traces.length

    trace = traces[0]
    assert trace.valid?

    # Span validation
    assert_equal 3, trace.spans.length
    first_span, second_span, third_span = trace.spans.to_a

    assert_equal :rack, first_span.name
    assert first_span[:ts].is_a?(Integer)
    assert first_span[:ts] > 0
    assert first_span[:d].is_a?(Integer)
    assert first_span[:d].between?(0, 5)
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
    clear_all!

    trace_id = ::Instana::Util.generate_id
    span_id = ::Instana::Util.generate_id

    header 'X-Instana-T', ::Instana::Util.id_to_header(trace_id)
    header 'X-Instana-S', ::Instana::Util.id_to_header(span_id)

    get '/mrlobster'
    assert last_response.ok?

    traces = ::Instana.processor.queued_traces
    assert_equal 1, traces.length

    trace = traces[0]
    assert trace.valid?

    # Span validation
    assert_equal 3, trace.spans.length
    first_span = trace.spans.to_a.first

    # Make sure context was picked up and continued in the resulting
    # trace
    assert_equal trace_id, trace.id
    assert_equal span_id, first_span[:p]
  end

  def test_start_span_with_tags
    clear_all!
    span = OpenTracing.start_span('my_app_entry')

    assert span.is_a?(::Instana::Span)
    assert_equal :my_app_entry, OpenTracing.current_trace.current_span.name

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

  def test_start_span_with_custom_start_time
    clear_all!
    now = Time.now
    now_in_ms = ::Instana::Util.time_to_ms(now)

    span = OpenTracing.start_span('my_app_entry', :start_time => now)

    assert span.is_a?(::Instana::Span)
    assert_equal :my_app_entry, OpenTracing.current_trace.current_span.name

    span.set_tag(:tag_integer, 1234)
    span.set_tag(:tag_boolean, true)
    span.set_tag(:tag_array, [1,2,3,4])
    span.set_tag(:tag_string, "1234")

    assert_equal 1234, span.tags(:tag_integer)
    assert_equal true, span.tags(:tag_boolean)
    assert_equal [1,2,3,4], span.tags(:tag_array)
    assert_equal "1234", span.tags(:tag_string)
    span.finish

    assert span[:ts].is_a?(Integer)
    assert_equal now_in_ms, span[:ts]
    assert span[:d].is_a?(Integer)
    assert span[:d].between?(0, 5)
  end

  def test_span_kind_translation
    clear_all!
    span = OpenTracing.start_span('my_app_entry')

    assert span.is_a?(::Instana::Span)
    assert_equal :my_app_entry, OpenTracing.current_trace.current_span.name

    span.set_tag(:'span.kind', :server)
    assert_equal :entry, span[:data][:sdk][:type]
    assert_equal :entry, span[:k]

    span.set_tag(:'span.kind', :consumer)
    assert_equal :entry, span[:data][:sdk][:type]
    assert_equal :entry, span[:k]

    span.set_tag(:'span.kind', :client)
    assert_equal :exit, span[:data][:sdk][:type]
    assert_equal :exit, span[:k]

    span.set_tag(:'span.kind', :producer)
    assert_equal :exit, span[:data][:sdk][:type]
    assert_equal :exit, span[:k]

    span[:data][:sdk].delete(:type)
    span.set_tag(:'span.kind', :blah)
    assert_equal :intermediate, span[:data][:sdk][:type]
    assert_equal :intermediate, span[:k]
    assert_equal :blah, span[:data][:sdk][:custom][:tags][:'span.kind']

    span.finish
  end

  def test_start_span_with_baggage
    clear_all!
    span = OpenTracing.start_span('my_app_entry')
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
    clear_all!
    span_tags = {:start_tag => 1234, :another_tag => 'tag_value'}

    ts_start = Time.now - 1 # Put start time a bit in the past
    ts_start_ms = ::Instana::Util.time_to_ms(ts_start)

    span = OpenTracing.start_span('my_app_entry', tags: span_tags, start_time: ts_start)
    sleep 0.1

    ts_finish = Time.now + 5 # Put end time in the future
    ts_finish_ms = ::Instana::Util.time_to_ms(ts_finish)

    span.finish(ts_finish)

    assert_equal ts_start_ms, span[:ts]
    assert_equal (ts_finish_ms - ts_start_ms), span[:d]

    assert_equal 1234, span[:data][:sdk][:custom][:tags][:start_tag]
    assert_equal 'tag_value', span[:data][:sdk][:custom][:tags][:another_tag]
  end

  def test_nested_spans_using_child_of
    clear_all!
    entry_span = OpenTracing.start_span(:rack)
    ac_span = OpenTracing.start_span(:action_controller, child_of: entry_span)
    av_span = OpenTracing.start_span(:action_view, child_of: ac_span)
    sleep 0.1
    av_span.finish
    ac_span.finish
    entry_span.finish

    traces = ::Instana.processor.queued_traces

    assert_equal 1, traces.length

    trace = traces.first
    first_span, second_span, third_span = trace.spans.to_a

    assert_equal 3, trace.spans.length
    assert trace.valid?

    # IDs
    assert_equal trace.id, first_span[:t]
    assert_equal trace.id, second_span[:t]
    assert_equal trace.id, third_span[:t]

    # Linkage
    assert first_span.is_root
    assert_equal first_span[:s], second_span[:p]
    assert_equal second_span[:s], third_span[:p]
  end

  def test_start_span_with_nested_spans
    clear_all!
    entry_span = OpenTracing.start_span(:rack)
    ac_span = OpenTracing.start_span(:action_controller)
    av_span = OpenTracing.start_span(:action_view)
    sleep 0.1
    av_span.finish
    ac_span.finish
    entry_span.finish

    traces = ::Instana.processor.queued_traces

    assert_equal 1, traces.length
    trace = traces.first
    assert trace.valid?
    assert_equal 3, trace.spans.length

    first_span, second_span, third_span = trace.spans.to_a

    # IDs
    assert_equal trace.id, first_span[:t]
    assert_equal trace.id, second_span[:t]
    assert_equal trace.id, third_span[:t]

    # Linkage
    assert first_span.is_root
    assert_equal first_span[:s], second_span[:p]
    assert_equal second_span[:s], third_span[:p]
  end

  def test_nested_spans_with_baggage
    clear_all!
    entry_span = OpenTracing.start_span(:rack)
    ac_span = OpenTracing.start_span(:action_controller)
    ac_span.set_baggage_item(:my_bag, 1)
    av_span = OpenTracing.start_span(:action_view)
    sleep 0.1
    av_span.finish
    ac_span.finish
    entry_span.finish

    traces = ::Instana.processor.queued_traces

    assert_equal 1, traces.length
    trace = traces.first
    assert trace.valid?
    assert_equal 3, trace.spans.length

    first_span, second_span, third_span = trace.spans.to_a

    # IDs
    assert_equal trace.id, first_span[:t]
    assert_equal trace.id, second_span[:t]
    assert_equal trace.id, third_span[:t]

    # Linkage
    assert first_span.is_root
    assert_equal first_span[:s], second_span[:p]
    assert_equal second_span[:s], third_span[:p]

    # Every span should have baggage
    assert_equal nil, first_span.get_baggage_item(:my_bag)
    assert_equal 1, second_span.get_baggage_item(:my_bag)
    assert_equal 1, third_span.get_baggage_item(:my_bag)
  end

  def test_context_should_carry_baggage
    clear_all!

    entry_span = OpenTracing.start_span(:rack)
    entry_span_context = entry_span.context

    ac_span = OpenTracing.start_span(:action_controller)
    ac_span.set_baggage_item(:my_bag, 1)
    ac_span_context = ac_span.context

    av_span = OpenTracing.start_span(:action_view)
    av_span_context = av_span.context

    sleep 0.1
    av_span.finish
    ac_span.finish
    entry_span.finish

    traces = ::Instana.processor.queued_traces

    assert_equal 1, traces.length
    trace = traces.first
    assert trace.valid?
    assert_equal 3, trace.spans.length

    assert_equal nil, entry_span_context.baggage[:my_bag]
    assert_equal 1, ac_span_context.baggage[:my_bag]
    assert_equal 1, av_span_context.baggage[:my_bag]
  end

  def test_baggage_with_complex_data
    clear_all!

    entry_span = OpenTracing.start_span(:rack)
    entry_span_context = entry_span.context

    ac_span = OpenTracing.start_span(:action_controller)

    ac_span.set_baggage_item(:integer, 1)
    ac_span.set_baggage_item(:float, 1.0123948293)
    ac_span.set_baggage_item(:hash, { :hash_sublevel => "blah",
                                      :another => {} })
    ac_span_context = ac_span.context

    av_span = OpenTracing.start_span(:action_view)
    av_span_context = av_span.context

    sleep 0.1
    av_span.finish
    ac_span.finish
    entry_span.finish

    traces = ::Instana.processor.queued_traces

    assert_equal 1, traces.length
    trace = traces.first
    assert trace.valid?
    assert_equal 3, trace.spans.length

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
