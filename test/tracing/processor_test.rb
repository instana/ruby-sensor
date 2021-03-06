# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2021

require 'test_helper'

class ProcessorTest < Minitest::Test
  def test_queued_spans_empty
    subject = Instana::Processor.new
    assert_equal [], subject.queued_spans
  end

  def test_queued_spans_valid_level
    clear_all!
    subject = Instana::Processor.new

    span_context = Instana::SpanContext.new('9', '8', 0)
    span = Instana::Span.new(:rack, parent_ctx: span_context)
    span2 = Instana::Span.new(:"net-http")

    subject.add_span(span)
    subject.add_span(span2)

    spans = subject.queued_spans
    valid_span, = spans

    assert_equal 1, spans.length
    assert_equal :"net-http", valid_span[:n]
  end

  def test_queued_spans_invalid_type
    subject = Instana::Processor.new
    subject.add_span(false)

    assert_equal [], subject.queued_spans
  end

  def test_send
    ENV['INSTANA_TEST'] = nil

    subject = Instana::Processor.new
    span = Instana::Span.new(:rack)
    subject.add_span(span)

    was_invoked = false

    subject.send do |spans|
      was_invoked = true
      rack_span, = spans

      assert_equal 1, spans.length
      assert_equal :rack, rack_span[:n]
    end

    assert was_invoked
  ensure
    ENV['INSTANA_TEST'] = 'true'
  end
end
