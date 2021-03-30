# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2021

require 'test_helper'

class FargateContainerTest < Minitest::Test
  def test_snapshot_observed
    container = JSON.parse(File.read('test/support/ecs/task.json'))['Containers'].first
    subject = Instana::Snapshot::FargateContainer.new(container, metadata_uri: 'https://10.10.10.10:8080/v3')

    stub_request(:get, 'https://10.10.10.10:8080/v3')
      .to_return(status: 200, body: File.read('test/support/ecs/container.json'))

    snapshot = subject.snapshot

    assert_equal Instana::Snapshot::FargateContainer::ID, snapshot[:name]
    assert_equal 'arn:aws:ecs:us-east-2:012345678910:task/9781c248-0edd-4cdb-9a93-f63cb662a5d3::~internal~ecs~pause', snapshot[:entityId]

    assert_equal "731a0d6a3b4210e2448339bc7015aaa79bfe4fa256384f4102db86ef94cbbc4c", snapshot[:data][:dockerId]
    assert_equal "ecs-nginx-5-internalecspause-acc699c0cbf2d6d11700", snapshot[:data][:dockerName]
    assert_equal "~internal~ecs~pause", snapshot[:data][:containerName]
    assert_equal "amazon/amazon-ecs-pause:0.1.0", snapshot[:data][:image]
    assert_equal "", snapshot[:data][:imageId]
    assert_equal "arn:aws:ecs:us-east-2:012345678910:task/9781c248-0edd-4cdb-9a93-f63cb662a5d3", snapshot[:data][:taskArn]
    assert_nil snapshot[:data][:taskDefinition]
    assert_nil snapshot[:data][:taskDefinitionVersion]
    assert_equal "default", snapshot[:data][:clusterArn]
    assert_equal "RESOURCES_PROVISIONED", snapshot[:data][:desiredStatus]
    assert_equal "RESOURCES_PROVISIONED", snapshot[:data][:knownStatus]
    assert_nil snapshot[:data][:ports]
    assert_equal({:cpu => 0, :memory => 0}, snapshot[:data][:limits])
    assert_equal "2018-02-01T20:55:08.366329616Z", snapshot[:data][:createdAt]
    assert_equal "2018-02-01T20:55:09.058354915Z", snapshot[:data][:startedAt]

    assert_nil subject.source
  end

  def test_snapshot_current
    container = JSON.parse(File.read('test/support/ecs/task.json'))['Containers'].last
    subject = Instana::Snapshot::FargateContainer.new(container, metadata_uri: 'https://10.10.10.10:8080/v3')

    stub_request(:get, 'https://10.10.10.10:8080/v3')
      .to_return(status: 200, body: File.read('test/support/ecs/container.json'))

    snapshot = subject.snapshot

    assert_equal Instana::Snapshot::FargateContainer::ID, snapshot[:name]
    assert_equal 'arn:aws:ecs:us-east-2:012345678910:task/9781c248-0edd-4cdb-9a93-f63cb662a5d3::nginx-curl', snapshot[:entityId]

    assert_equal "43481a6ce4842eec8fe72fc28500c6b52edcc0917f105b83379f88cac1ff3946", snapshot[:data][:dockerId]
    assert_equal "ecs-nginx-5-nginx-curl-ccccb9f49db0dfe0d901", snapshot[:data][:dockerName]
    assert_equal "nginx-curl", snapshot[:data][:containerName]
    assert_equal "nrdlngr/nginx-curl", snapshot[:data][:image]
    assert_equal "sha256:2e00ae64383cfc865ba0a2ba37f61b50a120d2d9378559dcd458dc0de47bc165", snapshot[:data][:imageId]
    assert_equal "arn:aws:ecs:us-east-2:012345678910:task/9781c248-0edd-4cdb-9a93-f63cb662a5d3", snapshot[:data][:taskArn]
    assert_nil snapshot[:data][:taskDefinition]
    assert_nil snapshot[:data][:taskDefinitionVersion]
    assert_equal "default", snapshot[:data][:clusterArn]
    assert_equal "RUNNING", snapshot[:data][:desiredStatus]
    assert_equal "RUNNING", snapshot[:data][:knownStatus]
    assert_nil snapshot[:data][:ports]
    assert_equal({:cpu => 512, :memory => 512}, snapshot[:data][:limits])
    assert_equal "2018-02-01T20:55:10.554941919Z", snapshot[:data][:createdAt]
    assert_equal "2018-02-01T20:55:11.064236631Z", snapshot[:data][:startedAt]
    assert_equal true, snapshot[:data][:instrumented]
    assert_equal "ruby", snapshot[:data][:runtime]

    assert_equal({hl: true, cp: "aws", e: "arn:aws:ecs:us-east-2:012345678910:task/9781c248-0edd-4cdb-9a93-f63cb662a5d3::nginx-curl"}, subject.source)
  end

  def test_snapshot_error
    stub_request(:get, 'https://10.10.10.10:8080/v3')
      .to_return(status: 500)

    container = JSON.parse(File.read('test/support/ecs/task.json'))['Containers'].first
    subject = Instana::Snapshot::FargateContainer.new(container, metadata_uri: 'https://10.10.10.10:8080/v3')

    assert_raises do
      subject.snapshot
    end
  end
end
