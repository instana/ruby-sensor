# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2021

require 'test_helper'

class LambdaFunctionTest < Minitest::Test
  def setup
    @subject = Instana::Snapshot::LambdaFunction.new
  end

  def test_snapshot
    Thread.current[:instana_function_arn] = 'test'

    assert_equal Instana::Snapshot::LambdaFunction::ID, @subject.snapshot[:name]
    assert_equal Thread.current[:instana_function_arn], @subject.snapshot[:entityId]
  ensure
    Thread.current[:instana_function_arn] = nil
  end

  def test_source
    Thread.current[:instana_function_arn] = 'test'

    assert @subject.source[:hl]
    assert_equal 'aws', @subject.source[:cp]
    assert_equal Thread.current[:instana_function_arn], @subject.source[:e]
  ensure
    Thread.current[:instana_function_arn] = nil
  end

  def test_host_name
    Thread.current[:instana_function_arn] = 'test'

    assert_equal Thread.current[:instana_function_arn], @subject.host_name
  ensure
    Thread.current[:instana_function_arn] = nil
  end
end
