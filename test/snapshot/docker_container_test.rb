# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2021

require 'test_helper'

class DockerContainerTest < Minitest::Test
  def test_container
    stub_request(:get, 'https://10.10.10.10:8080/v3/task/stats')
      .to_return(status: 200, body: File.read('test/support/ecs/stats.json'))

    container = JSON.parse(File.read('test/support/ecs/task.json'))['Containers'].first
    subject = Instana::Snapshot::DockerContainer.new(container, metadata_uri: 'https://10.10.10.10:8080/v3')

    snapshot = subject.snapshot

    assert_equal Instana::Snapshot::DockerContainer::ID, snapshot[:name]
    assert_equal 'arn:aws:ecs:us-east-2:012345678910:task/9781c248-0edd-4cdb-9a93-f63cb662a5d3::~internal~ecs~pause', snapshot[:entityId]

    assert_equal "731a0d6a3b4210e2448339bc7015aaa79bfe4fa256384f4102db86ef94cbbc4c", snapshot[:data][:Id]
    assert_equal "2018-02-01T20:55:08.366329616Z", snapshot[:data][:Created]
    assert_equal "2018-02-01T20:55:09.058354915Z", snapshot[:data][:Started]
    assert_equal "amazon/amazon-ecs-pause:0.1.0", snapshot[:data][:Image]
    assert_equal container['Labels'], snapshot[:data][:Labels]
    assert_nil snapshot[:data][:Ports]
    assert_equal "awsvpc", snapshot[:data][:NetworkMode]
  end

  def test_container_metrics
    stub_request(:get, 'https://10.10.10.10:8080/v3/task/stats')
      .to_return(status: 200, body: File.read('test/support/ecs/stats.json'))

    container = JSON.parse(File.read('test/support/ecs/task.json'))['Containers'].last
    subject = Instana::Snapshot::DockerContainer.new(container, metadata_uri: 'https://10.10.10.10:8080/v3')

    snapshot = subject.snapshot

    assert_equal Instana::Snapshot::DockerContainer::ID, snapshot[:name]
    assert_equal 'arn:aws:ecs:us-east-2:012345678910:task/9781c248-0edd-4cdb-9a93-f63cb662a5d3::nginx-curl', snapshot[:entityId]

    assert_equal 0.0030905127838258164, snapshot[:data][:cpu][:total_usage]
    assert_equal 0.0022809745982374286, snapshot[:data][:cpu][:user_usage]
    assert_equal 0.00031104199066874026, snapshot[:data][:cpu][:system_usage]
    assert_equal 0, snapshot[:data][:cpu][:throttling_count]
    assert_equal 0, snapshot[:data][:cpu][:throttling_time]
    assert_equal 5_890_048, snapshot[:data][:blkio][:blk_read]
    assert_equal 12288, snapshot[:data][:blkio][:blk_write]
    assert_equal 6_610_944, snapshot[:data][:memory][:active_anon]
    assert_equal 0, snapshot[:data][:memory][:active_file]
    assert_equal 0, snapshot[:data][:memory][:inactive_anon]
    assert_equal 2_158_592, snapshot[:data][:memory][:inactive_file]
    assert_equal 0, snapshot[:data][:memory][:total_cache]
    assert_equal 8_769_536, snapshot[:data][:memory][:total_rss]
    assert_equal 10_035_200, snapshot[:data][:memory][:usage]
    assert_equal 12_677_120, snapshot[:data][:memory][:max_usage]
    assert_equal 4_134_825_984, snapshot[:data][:memory][:limit]
    assert_equal({bytes: 40_000_257, dropped: 7, errors: 2, packet: 200_017}, snapshot[:data][:network][:rx])
    assert_equal({bytes: 20_000_511, dropped: 200_007, errors: 5, packet: 2}, snapshot[:data][:network][:tx])
  end

  def test_container_no_network
    stub_request(:get, 'https://10.10.10.10:8080/v3/task/stats')
      .to_return(status: 200, body: File.read('test/support/ecs/stats.json'))

    container = JSON.parse(File.read('test/support/ecs/task.json'))['Containers'][1]
    subject = Instana::Snapshot::DockerContainer.new(container, metadata_uri: 'https://10.10.10.10:8080/v3')

    snapshot = subject.snapshot
    assert_nil snapshot[:data][:network]
  end

  def test_snapshot_error
    stub_request(:get, 'https://10.10.10.10:8080/v3/task/stats')
      .to_return(status: 500)

    container = JSON.parse(File.read('test/support/ecs/task.json'))['Containers'].first
    subject = Instana::Snapshot::DockerContainer.new(container, metadata_uri: 'https://10.10.10.10:8080/v3')

    assert_raises do
      subject.snapshot
    end
  end
end
