# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2021

require 'test_helper'

class DeltableTest < Minitest::Test
  include Instana::Snapshot::Deltable

  def test_delta
    subject = {a: {b: 5}}

    assert_equal 5, delta(:a, :b, obj: subject, compute: ->(o, n) { o + n })
    assert_equal 10, delta(:a, :b, obj: subject, compute: ->(o, n) { o + n })

    assert_nil delta(:a, :c, obj: subject, compute: ->(o, n) { o + n })
  end
end
