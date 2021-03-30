# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2021

require 'test_helper'

class UtilTest < Minitest::Test
  def test_get_rb_source_error
    assert_equal({ error: "Only Ruby source files are allowed. (*.rb)" }, Instana::Util.get_rb_source('invalid.txt'))
  end
end
