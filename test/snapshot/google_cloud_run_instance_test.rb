# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2021

require 'test_helper'

class GoogleCloudRunInstanceTest < Minitest::Test
  def test_snapshot
    ENV['K_SERVICE'] = 'test_service'
    ENV['K_CONFIGURATION'] = 'test_config'
    ENV['K_REVISION'] = 'test_revision'
    ENV['PORT'] = 'test_port'

    stub_request(:get, 'http://10.10.10.10//computeMetadata/v1/instance/id')
      .to_return(status: 200, body: 'test_instance_id')
    stub_request(:get, 'http://10.10.10.10//computeMetadata/v1/instance/region')
      .to_return(status: 200, body: 'region/number/test_region')
    stub_request(:get, 'http://10.10.10.10//computeMetadata/v1/project/numericProjectId')
      .to_return(status: 200, body: 'numericProjectId')
    stub_request(:get, 'http://10.10.10.10//computeMetadata/v1/project/projectId')
      .to_return(status: 200, body: 'projectId')

    subject = Instana::Snapshot::GoogleCloudRunInstance.new(metadata_uri: 'http://10.10.10.10/')
    snapshot = subject.snapshot

    assert_equal Instana::Snapshot::GoogleCloudRunInstance::ID, snapshot[:name]
    assert_equal 'test_instance_id', snapshot[:entityId]

    assert_equal "ruby", snapshot[:data][:runtime]
    assert_equal "test_region", snapshot[:data][:region]
    assert_equal "test_service", snapshot[:data][:service]
    assert_equal "test_config", snapshot[:data][:configuration]
    assert_equal "test_revision", snapshot[:data][:revision]
    assert_equal "test_instance_id", snapshot[:data][:instanceId]
    assert_equal "test_port", snapshot[:data][:port]
    assert_equal "numericProjectId", snapshot[:data][:numericProjectId]
    assert_equal "projectId", snapshot[:data][:projectId]
  ensure
    ENV['K_SERVICE'] = nil
    ENV['K_CONFIGURATION'] = nil
    ENV['K_REVISION'] = nil
    ENV['PORT'] = nil
  end

  def test_snapshot_error
    stub_request(:get, 'http://10.10.10.10//computeMetadata/v1/instance/id')
      .to_return(status: 500)

    subject = Instana::Snapshot::GoogleCloudRunInstance.new(metadata_uri: 'http://10.10.10.10/')

    assert_raises do
      subject.snapshot
    end
  end

  def test_source
    stub_request(:get, 'http://10.10.10.10//computeMetadata/v1/instance/id')
      .to_return(status: 200, body: 'test_instance_id')
    subject = Instana::Snapshot::GoogleCloudRunInstance.new(metadata_uri: 'http://10.10.10.10/')
    source = subject.source

    assert source[:hl]
    assert_equal 'gcp', source[:cp]
    assert_equal 'test_instance_id', source[:e]
  end

  def test_host_name
    ENV['K_REVISION'] = 'test_revision'
    subject = Instana::Snapshot::GoogleCloudRunInstance.new(metadata_uri: 'http://10.10.10.10/')

    assert_equal 'gcp:cloud-run:revision:test_revision', subject.host_name
  ensure
    ENV['K_REVISION'] = nil
  end
end
