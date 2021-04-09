# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2021

require 'test_helper'

class GoogleCloudRunProcessTest < Minitest::Test
  def test_snapshot
    ENV['K_REVISION'] = 'test'
    stub_request(:get, 'http://10.10.10.10//computeMetadata/v1/instance/id')
      .to_return(status: 200, body: 'test_instance_id')

    subject = Instana::Snapshot::GoogleCloudRunProcess.new(metadata_uri: 'http://10.10.10.10/')
    snapshot = subject.snapshot

    assert_equal Instana::Snapshot::GoogleCloudRunProcess::ID, snapshot[:name]
    assert_equal 'test_instance_id', snapshot[:data][:container]
    assert_equal 'gcpCloudRunInstance', snapshot[:data][:containerType]
    assert_equal 'gcp:cloud-run:revision:test', snapshot[:data][:'com.instana.plugin.host.name']
  ensure
    ENV['K_REVISION'] = nil
  end

  def test_snapshot_error
    stub_request(:get, 'http://10.10.10.10//computeMetadata/v1/instance/id')
      .to_return(status: 500)

    subject = Instana::Snapshot::GoogleCloudRunProcess.new(metadata_uri: 'http://10.10.10.10/')

    assert_raises do
      subject.snapshot
    end
  end
end
