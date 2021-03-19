# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2021

require 'test_helper'

class ProcessInfoTest < Minitest::Test
  def test_osx_argument_stripping
    host_os = RbConfig::CONFIG['host_os']
    RbConfig::CONFIG['host_os'] = 'darwin'

    subject = Instana::Backend::ProcessInfo.new(OpenStruct.new(cmdline: 'test INSTANA_TEST=1 KV=2'))
    assert_equal ['KV=2'], subject.arguments
  ensure
    RbConfig::CONFIG['host_os'] = host_os
  end

  def test_linux_argument_stripping
    host_os = RbConfig::CONFIG['host_os']
    RbConfig::CONFIG['host_os'] = 'linux'

    subject = Instana::Backend::ProcessInfo.new(OpenStruct.new(cmdline: 'test INSTANA_TEST=1 KV=2'))
    assert_equal ['INSTANA_TEST=1', 'KV=2'], subject.arguments
  ensure
    RbConfig::CONFIG['host_os'] = host_os
  end

  def test_no_proc
    subject = Instana::Backend::ProcessInfo.new(OpenStruct.new(pid: 0))

    assert_equal 0, subject.parent_pid
    assert_nil subject.cpuset
    assert_nil subject.sched_pid
    refute subject.in_container?
  end

  def test_cpuset_proc
    subject = Instana::Backend::ProcessInfo.new(OpenStruct.new(pid: 0))

    FakeFS do
      FakeFS::FileSystem.clone('test/support/proc', '/proc')
      assert_equal '/', subject.cpuset
      refute subject.in_container?
    end
  end

  def test_sched_pid
    subject = Instana::Backend::ProcessInfo.new(OpenStruct.new(pid: 1))

    FakeFS do
      FakeFS::FileSystem.clone('test/support/proc', '/proc')
      refute_equal '/', subject.cpuset

      assert subject.in_container?
      assert_equal 35, subject.sched_pid
      assert subject.from_parent_namespace
      assert_equal subject.sched_pid, subject.parent_pid
    end
  end
end
