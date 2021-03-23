# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2021

require 'test_helper'

class FargateTaskTest < Minitest::Test
  def setup
    @subject = Instana::Snapshot::FargateTask.new(metadata_uri: 'https://10.10.10.10:8080/v3')

    ENV['INSTANA_ZONE'] = 'test'
    ENV['INSTANA_TAGS'] = 'test=a,b,c'
  end

  def teardown
    ENV['INSTANA_ZONE'] = nil
    ENV['INSTANA_TAGS'] = nil
  end

  def test_snapshot
    stub_request(:get, 'https://10.10.10.10:8080/v3/task')
      .to_return(status: 200, body: File.read('test/support/ecs/task.json'))

    snapshot = @subject.snapshot

    assert_equal Instana::Snapshot::FargateTask::ID, snapshot[:name]
    assert_equal 'arn:aws:ecs:us-east-2:012345678910:task/9781c248-0edd-4cdb-9a93-f63cb662a5d3', snapshot[:entityId]

    assert_equal "arn:aws:ecs:us-east-2:012345678910:task/9781c248-0edd-4cdb-9a93-f63cb662a5d3", snapshot[:data][:taskArn]
    assert_equal "default", snapshot[:data][:clusterArn]
    assert_equal "nginx", snapshot[:data][:taskDefinition]
    assert_equal "5", snapshot[:data][:taskDefinitionVersion]
    assert_equal "us-east-2b", snapshot[:data][:availabilityZone]
    assert_equal "RUNNING", snapshot[:data][:desiredStatus]
    assert_equal "RUNNING", snapshot[:data][:knownStatus]
    assert_equal "2018-02-01T20:55:09.372495529Z", snapshot[:data][:pullStartedAt]
    assert_equal "2018-02-01T20:55:10.552018345Z", snapshot[:data][:pullStoppedAt]
    assert_equal "test", snapshot[:data][:instanaZone]
    assert_equal({"test" => "a", "b" => nil, "c" => nil}, snapshot[:data][:tags])
  end

  def test_snapshot_error
    stub_request(:get, 'https://10.10.10.10:8080/v3/task')
      .to_return(status: 500)

    assert_raises do
      @subject.snapshot
    end
  end
end
