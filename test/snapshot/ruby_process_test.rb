# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2021

require 'test_helper'

class RubyProcessTest < Minitest::Test
  def test_snapshot
    subject = Instana::Snapshot::RubyProcess.new
    snapshot = subject.snapshot

    assert_equal Instana::Snapshot::RubyProcess::ID, snapshot[:name]
    assert_equal Process.pid.to_s, snapshot[:entityId]
    assert_equal File.basename($0), snapshot[:data][:name]
  end

  def test_snapshot_with_rails_defined_but_no_rails_application
    Object.send(:const_set, :Rails, Module.new {|mod| def respond_to?; return false; end})
    subject = Instana::Snapshot::RubyProcess.new
    snapshot = subject.snapshot

    assert_equal Instana::Snapshot::RubyProcess::ID, snapshot[:name]
    assert_equal Process.pid.to_s, snapshot[:entityId]
    assert_equal File.basename($0), snapshot[:data][:name]
  ensure
    Object.send(:remove_const, :Rails)
  end
end
