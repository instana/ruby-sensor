# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2021

require 'test_helper'

require 'rails'
require 'action_cable'

require 'ostruct'
require 'logger'

class RailsActionCableTest < Minitest::Test
  def setup
    skip unless defined?(::ActionCable::Connection::Base)
  end

  def test_config_defaults
    assert ::Instana.config[:action_cable].is_a?(Hash)
    assert ::Instana.config[:action_cable].key?(:enabled)
    assert_equal true, ::Instana.config[:action_cable][:enabled]

    activator = ::Instana::Activators::ActionCable.new
    assert_equal true, activator.can_instrument?
  end

  def test_instrumentation_disabled
    ::Instana.config[:action_cable][:enabled] = false

    activator = ::Instana::Activators::ActionCable.new
    assert_equal false, activator.can_instrument?
  end

  def test_transmit_no_parent
    clear_all!

    connection = mock_connection
    channel_klass = Class.new(ActionCable::Channel::Base)

    channel_klass
      .new(connection, :test)
      .send(:transmit, 'Sample message', via: nil)

    span, rest = Instana.processor.queued_spans
    data = span[:data]

    assert_nil rest
    assert :"rpc-server", span[:n]
    assert :actioncable, data[:rpc][:flavor]
    assert channel_klass.to_s, data[:rpc][:call]
    assert :transmit, data[:rpc][:call_type]
    assert Socket.gethostname, data[:rpc][:host]
  end

  def test_transmit_parent
    clear_all!

    connection = mock_connection
    connection.instance_variable_set(
      :@instana_trace_context,
      Instana::SpanContext.new('ABC', 'ABC')
    )
    channel_klass = Class.new(ActionCable::Channel::Base)

    channel_klass
      .new(connection, :test)
      .send(:transmit, 'Sample message', via: 'Important')

    span, rest = Instana.processor.queued_spans
    data = span[:data]

    assert_nil rest
    assert 'ABC', span[:t]
    assert :"rpc-server", span[:n]
    assert :actioncable, data[:rpc][:flavor]
    assert channel_klass.to_s, data[:rpc][:call]
    assert :transmit, data[:rpc][:call_type]
    assert Socket.gethostname, data[:rpc][:host]
  end

  def test_action_no_parent
    clear_all!

    connection = mock_connection
    channel_klass = Class.new(ActionCable::Channel::Base) do
      def sample
        raise unless Instana.tracer.tracing?
      end
    end

    channel_klass
      .new(connection, :test)
      .perform_action('action' => 'sample')

    span, rest = Instana.processor.queued_spans
    data = span[:data]

    assert_nil rest
    assert :"rpc-server", span[:n]
    assert :actioncable, data[:rpc][:flavor]
    assert "#{channel_klass}#sample", data[:rpc][:call]
    assert :action, data[:rpc][:call_type]
    assert Socket.gethostname, data[:rpc][:host]
  end

  def test_action_parent
    clear_all!

    connection = mock_connection
    connection.instance_variable_set(
      :@instana_trace_context,
      Instana::SpanContext.new('ABC', 'ABC')
    )
    channel_klass = Class.new(ActionCable::Channel::Base) do
      def sample
        raise unless Instana.tracer.tracing?
      end
    end

    channel_klass
      .new(connection, :test)
      .perform_action('action' => 'sample')

    span, rest = Instana.processor.queued_spans
    data = span[:data]

    assert_nil rest
    assert 'ABC', span[:t]
    assert :"rpc-server", span[:n]
    assert :actioncable, data[:rpc][:flavor]
    assert "#{channel_klass}#sample", data[:rpc][:call]
    assert :action, data[:rpc][:call_type]
    assert Socket.gethostname, data[:rpc][:host]
  end

  private

  def mock_connection
    server = OpenStruct.new(
      logger: Logger.new('/dev/null'),
      worker_pool: nil,
      config: OpenStruct.new(log_tags: [])
    )
    connection = ActionCable::Connection::Base.new(server, {})
    connection.define_singleton_method(:transmit) { |*_args, **_kwargs| true }
    connection
  end
end
