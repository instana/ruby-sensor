# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2021

require 'test_helper'

class GcSnapshotTest < Minitest::Test
  def test_report
    subject = Instana::Backend::GCSnapshot.instance
    assert subject.report.is_a?(Hash)
  end
end
