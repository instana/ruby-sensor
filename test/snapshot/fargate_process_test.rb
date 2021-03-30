# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2021

require 'test_helper'

class FargateProcessTest < Minitest::Test
  def setup
    @subject = Instana::Snapshot::FargateProcess.new(metadata_uri: 'https://10.10.10.10:8080/v3')
  end

  def test_snapshot
    stub_request(:get, 'https://10.10.10.10:8080/v3')
      .to_return(status: 200, body: File.read('test/support/ecs/container.json'))
    stub_request(:get, 'https://10.10.10.10:8080/v3/task')
      .to_return(status: 200, body: File.read('test/support/ecs/task.json'))

    snapshot = @subject.snapshot

    assert_equal Instana::Snapshot::FargateProcess::ID, snapshot[:name]
    assert_equal Process.pid.to_s, snapshot[:entityId]

    assert_equal 'docker', snapshot[:data][:containerType]
    assert_equal '43481a6ce4842eec8fe72fc28500c6b52edcc0917f105b83379f88cac1ff3946', snapshot[:data][:container]
    assert_equal 'arn:aws:ecs:us-east-2:012345678910:task/9781c248-0edd-4cdb-9a93-f63cb662a5d3', snapshot[:data][:'com.instana.plugin.host.name']
  end

  def test_snapshot_error
    stub_request(:get, 'https://10.10.10.10:8080/v3')
      .to_return(status: 500)

    assert_raises do
      @subject.snapshot
    end
  end
end
