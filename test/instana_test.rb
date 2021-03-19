# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2016

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

  def test_that_it_has_a_tracer
    refute_nil ::Instana.tracer
  end

  def test_that_it_has_a_config
    refute_nil ::Instana.config
  end
end
