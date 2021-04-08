# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2021

require 'test_helper'

class SpanContextTest < Minitest::Test
  def test_to_hash
    subject = Instana::SpanContext.new('trace', 'span')
    assert_equal({trace_id: 'trace', span_id: 'span'}, subject.to_hash)
  end

  def test_invalid
    subject = Instana::SpanContext.new(nil, nil)
    refute subject.valid?
  end

  def test_flags_level_zero
    subject = Instana::SpanContext.new('trace', 'span', 0, {external_state: 'cn=test'})
    assert_equal '00-000000000000000000000000000trace-000000000000span-00', subject.trace_parent_header
    assert_equal 'cn=test', subject.trace_state_header
  end
end
