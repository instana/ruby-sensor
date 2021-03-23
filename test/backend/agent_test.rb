# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2021

require 'test_helper'

class AgentTest < Minitest::Test
  def test_host
    subject = Instana::Backend::Agent.new
    assert_nil subject.delegate
    subject.setup
    assert subject.delegate.is_a?(Instana::Backend::HostAgent)
  end

  def test_fargate
    ENV['ECS_CONTAINER_METADATA_URI'] = 'https://10.10.10.10:9292/v3'
    ENV['INSTANA_ENDPOINT_URL'] = 'http://example.com'

    stub_request(:get, 'https://10.10.10.10:9292/v3/task')
      .to_return(status: 200, body: File.read('test/support/ecs/task.json'))

    subject = Instana::Backend::Agent.new(fargate_metadata_uri: 'https://10.10.10.10:9292/v3')
    assert_nil subject.delegate
    subject.setup
    assert subject.delegate.is_a?(Instana::Backend::ServerlessAgent)
  ensure
    ENV['INSTANA_ENDPOINT_URL'] = nil
    ENV['ECS_CONTAINER_METADATA_URI'] = nil
  end

  def test_fargate_error
    ENV['ECS_CONTAINER_METADATA_URI'] = 'https://10.10.10.10:9292/v3'
    ENV['INSTANA_ENDPOINT_URL'] = 'http://example.com'

    stub_request(:get, 'https://10.10.10.10:9292/v3/task')
      .to_return(status: 500)

    subject = Instana::Backend::Agent.new(logger: Logger.new('/dev/null'))
    assert_nil subject.delegate
    subject.setup
    assert subject.delegate.is_a?(Instana::Backend::ServerlessAgent)
  ensure
    ENV['INSTANA_ENDPOINT_URL'] = nil
    ENV['ECS_CONTAINER_METADATA_URI'] = nil
  end

  def test_delegate_super
    subject = Instana::Backend::Agent.new
    assert_raises NoMethodError do
      subject.invalid
    end

    refute subject.respond_to?(:invalid)
  end
end
