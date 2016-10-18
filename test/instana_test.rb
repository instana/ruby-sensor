require 'test_helper'

class InstanaTest < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil ::Instana::VERSION
  end

  def test_that_it_has_a_logger
    refute_nil ::Instana.logger
  end

  def test_that_it_has_an_agent
    refute_nil ::Instana.agent
  end
end
