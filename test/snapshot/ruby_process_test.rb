# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2021

require 'test_helper'

class RubyProcessTest < Minitest::Test
  def test_snapshot
    subject = Instana::Snapshot::RubyProcess.new
    snapshot = subject.snapshot

    assert_equal Instana::Snapshot::RubyProcess::ID, snapshot[:name]
    assert_equal Process.pid.to_s, snapshot[:entityId]
  end
end
