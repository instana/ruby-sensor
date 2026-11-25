# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2021

require 'test_helper'

class LambdaFunctionTest < Minitest::Test
  def setup
    @subject = Instana::Snapshot::LambdaFunction.new
  end

  def test_snapshot
    Fiber[:instana_function_arn] = 'test'

    assert_equal Instana::Snapshot::LambdaFunction::ID, @subject.snapshot[:name]
    assert_equal Fiber[:instana_function_arn], @subject.snapshot[:entityId]
  ensure
    Fiber[:instana_function_arn] = nil
  end

  def test_source
    Fiber[:instana_function_arn] = 'test'

    assert @subject.source[:hl]
    assert_equal 'aws', @subject.source[:cp]
    assert_equal Fiber[:instana_function_arn], @subject.source[:e]
  ensure
    Fiber[:instana_function_arn] = nil
  end

  def test_host_name
    Fiber[:instana_function_arn] = 'test'

    assert_equal Fiber[:instana_function_arn], @subject.host_name
  ensure
    Fiber[:instana_function_arn] = nil
  end
end
