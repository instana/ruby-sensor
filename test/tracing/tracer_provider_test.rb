# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2021

require 'test_helper'
require 'instana/trace/tracer_provider'

class TracerProviderTest < Minitest::Test
  def setup
    @tracer_provider = Instana.tracer_provider
  end

  def test_tracer
    # This tests the global tracer is the same as tracer from tracer_provider
    assert_equal Instana.tracer, @tracer_provider.tracer("instana_tracer")
  end
end
