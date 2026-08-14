# (c) Copyright IBM Corp. 2026

require 'test_helper'
require 'instana/exporter/otlp/background_job_converter'

class BackgroundJobConverterTest < Minitest::Test
  def test_sidekiq_client_conversion
    span = create_span('sidekiq-client', {
                         'sidekiq-client': { queue: 'default', job_id: '123', job: 'TestWorker', 'redis-url': 'localhost:6379' }
                       })
    converter = Instana::Exporter::Otlp::BackgroundJobConverter.new(span)
    attrs = converter.send(:convert_attributes)

    assert_equal 'sidekiq', attrs['messaging.system']
    assert_equal 'default', attrs['messaging.destination.name']
    assert_equal 'publish', attrs['messaging.operation']
    assert_equal '123', attrs['messaging.message.id']
    assert_equal 'TestWorker', attrs['messaging.consumer.group.name']
    assert_equal 'localhost', attrs['server.address']
    assert_equal 6379, attrs['server.port']
  end

  def test_sidekiq_worker_conversion
    span = create_span('sidekiq-worker', {
                         'sidekiq-worker': { queue: 'critical', job_id: '456', job: 'EmailWorker', 'redis-url': 'redis.local:6380' }
                       })
    converter = Instana::Exporter::Otlp::BackgroundJobConverter.new(span)
    attrs = converter.send(:convert_attributes)

    assert_equal 'sidekiq', attrs['messaging.system']
    assert_equal 'critical', attrs['messaging.destination.name']
    assert_equal 'process', attrs['messaging.operation']
    assert_equal '456', attrs['messaging.message.id']
    assert_equal 'EmailWorker', attrs['messaging.consumer.group.name']
  end

  def test_resque_client_conversion
    span = create_span('resque-client', {
                         'resque-client': { queue: 'low', job_id: '789', job: 'ReportWorker', 'redis-url': '127.0.0.1:6379' }
                       })
    converter = Instana::Exporter::Otlp::BackgroundJobConverter.new(span)
    attrs = converter.send(:convert_attributes)

    assert_equal 'resque', attrs['messaging.system']
    assert_equal 'low', attrs['messaging.destination.name']
    assert_equal 'publish', attrs['messaging.operation']
  end

  def test_resque_worker_conversion
    span = create_span('resque-worker', {
                         'resque-worker': { queue: 'high', job_id: '101', job: 'DataWorker' }
                       })
    converter = Instana::Exporter::Otlp::BackgroundJobConverter.new(span)
    attrs = converter.send(:convert_attributes)

    assert_equal 'resque', attrs['messaging.system']
    assert_equal 'process', attrs['messaging.operation']
  end

  def test_extract_host
    span = create_span('sidekiq-client', {})
    converter = Instana::Exporter::Otlp::BackgroundJobConverter.new(span)

    assert_equal 'localhost', converter.send(:extract_host, 'localhost:6379')
    assert_equal 'redis.local', converter.send(:extract_host, 'redis.local:6380')
    assert_nil converter.send(:extract_host, nil)
  end

  def test_extract_port
    span = create_span('sidekiq-client', {})
    converter = Instana::Exporter::Otlp::BackgroundJobConverter.new(span)

    assert_equal 6379, converter.send(:extract_port, 'localhost:6379')
    assert_equal 6380, converter.send(:extract_port, 'redis.local:6380')
    assert_nil converter.send(:extract_port, 'invalid')
    assert_nil converter.send(:extract_port, nil)
  end

  def test_missing_data
    span = create_span('sidekiq-client', {})
    converter = Instana::Exporter::Otlp::BackgroundJobConverter.new(span)
    attrs = converter.send(:convert_attributes)

    assert_empty attrs
  end

  # --- span_name tests ---

  def test_span_name_sidekiq_client_publish
    span = create_span('sidekiq-client', { 'sidekiq-client': { queue: 'default', job: 'MyWorker' } })
    result = Instana::Exporter::Otlp::BackgroundJobConverter.new(span).convert
    assert_equal 'default publish', result[:name]
  end

  def test_span_name_sidekiq_worker_process
    span = create_span('sidekiq-worker', { 'sidekiq-worker': { queue: 'critical', job: 'MyWorker' } })
    result = Instana::Exporter::Otlp::BackgroundJobConverter.new(span).convert
    assert_equal 'critical process', result[:name]
  end

  def test_span_name_resque_client_publish
    span = create_span('resque-client', { 'resque-client': { queue: 'low' } })
    result = Instana::Exporter::Otlp::BackgroundJobConverter.new(span).convert
    assert_equal 'low publish', result[:name]
  end

  def test_span_name_resque_worker_process
    span = create_span('resque-worker', { 'resque-worker': { queue: 'high' } })
    result = Instana::Exporter::Otlp::BackgroundJobConverter.new(span).convert
    assert_equal 'high process', result[:name]
  end

  def test_span_name_falls_back_to_operation_when_no_queue
    span = create_span('sidekiq-worker', { 'sidekiq-worker': {} })
    result = Instana::Exporter::Otlp::BackgroundJobConverter.new(span).convert
    assert_equal 'process', result[:name]
  end

  private

  def create_span(name, data)
    span = Instana::Span.new(name.to_sym)
    span[:data] = data
    span.close
    span
  end
end
