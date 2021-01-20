require 'test_helper'

class InstrumentedRequestTest < Minitest::Test
	def test_skip_trace_with_header
    req = Instana::InstrumentedRequest.new(
      'HTTP_X_INSTANA_L' => '0;sample-data'
    )
    
		assert req.skip_trace?
	end
  
  def test_skip_trace_without_header
    req = Instana::InstrumentedRequest.new({})
    
    refute req.skip_trace?
  end
  
  def test_incomming_context
    id = Instana::Util.generate_id
    req = Instana::InstrumentedRequest.new(
      'HTTP_X_INSTANA_L' => '1',
      'HTTP_X_INSTANA_T' => id,
      'HTTP_X_INSTANA_S' => id
    )
    
    expected = {
      trace_id: id,
      span_id: id,
      level: '1'
    }
    
    assert_equal expected, req.incoming_context
  end
  
  def test_request_tags
    ::Instana.agent.extra_headers = %w(X-Capture-This)
    req = Instana::InstrumentedRequest.new(
      'HTTP_HOST' => 'example.com',
      'REQUEST_METHOD' => 'GET',
      'HTTP_X_CAPTURE_THIS' => 'that',
      'PATH_INFO' => '/'
    )
    
    expected = {
      method: 'GET',
      url: '/',
      host: 'example.com',
      header: {
        "X-Capture-This": 'that'
      }
    }
    
    assert_equal expected, req.request_tags
    ::Instana.agent.extra_headers = nil
  end
  
end