# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2021

require 'test_helper'

class ActivatorTest < Minitest::Test
  def test_start
    refute_nil Instana::Activator.trace_point
    assert Instana::Activator.trace_point.enabled?
  end

  def test_klass_call
    assert_equal [], Instana::Activator.call
  end

  def test_instance_call
    subject = Class.new(Instana::Activator) do
      def can_instrument?
        true
      end

      def instrument
        true
      end
    end

    assert_equal 1, Instana::Activator.call.length
    assert subject.call
  end
end
