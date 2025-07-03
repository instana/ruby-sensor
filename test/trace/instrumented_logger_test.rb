# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2021

require 'test_helper'

class InstrumentedLoggerTest < Minitest::Test
  def setup
    clear_all!
  end

  def test_log_warn_error
    subject = Instana::InstrumentedLogger.new('/dev/null')

    Instana::Tracer.in_span(:test_logging) do
      subject.warn('warn')
      subject.debug('test')
      subject.error('error')
    end

    spans = ::Instana.processor.queued_spans

    warn_span, error_span, = *spans

    assert_equal :log, warn_span[:n]
    assert_equal 'warn', warn_span[:data][:log][:message]
    assert_equal 'Warn', warn_span[:data][:log][:level]

    assert_equal :log, error_span[:n]
    assert_equal 'error', error_span[:data][:log][:message]
    assert_equal 'Error', error_span[:data][:log][:level]
  end

  def test_no_trace
    subject = Instana::InstrumentedLogger.new('/dev/null')
    subject.warn('warn')

    assert_equal [], ::Instana.processor.queued_spans
  end
end
