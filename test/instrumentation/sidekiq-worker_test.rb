require 'test_helper'

class SidekiqServerTest < Minitest::Test
  def test_config_defaults
    assert ::Instana.config[:'sidekiq-worker'].is_a?(Hash)
    assert ::Instana.config[:'sidekiq-worker'].key?(:enabled)
    assert_equal true, ::Instana.config[:'sidekiq-worker'][:enabled]
  end

  def test_successful_worker_starts_new_trace
    clear_all!

    $sidekiq_mode = :server
    inject_instrumentation

    processor = ::Sidekiq::Processor.new(
      SidekiqManagerMock.new('SidekiqJobOne')
    )
    processor.start
    sleep 1
    assert_new_successful_trace
    processor.terminate

    $sidekiq_mode = :client
  end

  def test_failed_worker_starts_new_trace
    clear_all!

    $sidekiq_mode = :server
    inject_instrumentation

    processor = ::Sidekiq::Processor.new(
      SidekiqManagerMock.new('SidekiqJobTwo')
    )
    processor.start
    sleep 1
    assert_new_failed_trace
    processor.terminate

    $sidekiq_mode = :client
  end

  private

  def inject_instrumentation
    # Add the instrumentation again to ensure injection in server mode
    ::Sidekiq.configure_server do |cfg|
      cfg.server_middleware do |chain|
        chain.add ::Instana::Instrumentation::SidekiqWorker
      end
    end
  end

  def assert_new_successful_trace
    assert_equal 1, ::Instana.processor.queue_count
    worker_trace = Instana.processor.queued_traces.first

    assert_equal 1, worker_trace.spans.count
    span = worker_trace.spans.first

    assert_equal :sdk, span[:n]
    data = span[:data][:sdk]

    assert_equal :'sidekiq-worker', data[:name]
    assert_equal 'some_random_queue', data[:custom][:'sidekiq-worker'][:queue]
    assert_equal 'SidekiqJobOne', data[:custom][:'sidekiq-worker'][:job]
    assert_equal false, data[:custom][:'sidekiq-worker'][:retry]
    assert_equal '123456789', data[:custom][:'sidekiq-worker'][:job_id]
  end

  def assert_new_failed_trace
    assert_equal 1, ::Instana.processor.queue_count
    worker_trace = Instana.processor.queued_traces.first

    assert_equal 1, worker_trace.spans.count
    span = worker_trace.spans.first

    assert_equal :sdk, span[:n]
    data = span[:data][:sdk]

    assert_equal :'sidekiq-worker', data[:name]
    assert_equal 'some_random_queue', data[:custom][:'sidekiq-worker'][:queue]
    assert_equal 'SidekiqJobTwo', data[:custom][:'sidekiq-worker'][:job]
    assert_equal false, data[:custom][:'sidekiq-worker'][:retry]
    assert_equal '123456789', data[:custom][:'sidekiq-worker'][:job_id]

    assert_equal true, data[:custom][:'sidekiq-worker'][:error]
    assert_equal 'Fail to execute the job', data[:custom][:log][:message]
  end

  class RedisFetcherMock
    class << self
      attr_reader :worker_klass
    end

    def initialize(*_args)
      @received = false
    end

    def retrieve_work
      return if @received
      @received = true

      OpenStruct.new(
        queue: 'some_random_queue',
        job: <<-JSON
        {
          "class":"#{self.class.worker_klass}",
          "args":[1,2,3],
          "retry":false,
          "queue":"some_random_queue",
          "jid":"123456789"
        }
        JSON
      )
    end
  end

  class SidekiqManagerMock
    def initialize(worker_klass)
      @worker_klass = worker_klass
    end

    def processor_stopped(*args); end
    def processor_died(*args); end

    def options
      redis_mock_class = Class.new(RedisFetcherMock)
      redis_mock_class.instance_eval "@worker_klass = \"#{@worker_klass}\""
      { fetch: redis_mock_class }
    end
  end
end
