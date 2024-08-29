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

  def test_limited_activated_set
    ENV['INSTANA_ACTIVATE_SET'] = 'rack,rails'
    subject = activated_set
    assert_instance_of Set, subject
    assert_equal 2, subject.length
    assert_includes subject, 'rack'
    assert_includes subject, 'rails'
  ensure
    ENV.delete('INSTANA_ACTIVATE_SET')
  end

  def test_unlimited_activated_set
    ENV.delete('INSTANA_ACTIVATE_SET')
    subject = activated_set
    assert_instance_of Set, subject
    assert_equal 32, subject.length
  ensure
    ENV.delete('INSTANA_ACTIVATE_SET')
  end
end
