require 'test_helper'

class SidekiqServerTest < Minitest::Test
  def test_config_defaults
    assert ::Instana.config[:'sidekiq-worker'].is_a?(Hash)
    assert ::Instana.config[:'sidekiq-worker'].key?(:enabled)
    assert_equal true, ::Instana.config[:'sidekiq-worker'][:enabled]
  end

  def test_worker_starts_new_trace
    clear_all!

    $sidekiq_mode = :server
    inject_instrumentation

    processor = ::Sidekiq::Processor.new(SidekiqManagerMock.new)
    processor.start
    sleep 1
    assert_new_trace_recorded
    processor.terminate

    $sidekiq_mode = :client
  end

  private

  def assert_new_trace_recorded
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
    assert_equal 'a79be9cabc60ceaa9a211437', data[:custom][:'sidekiq-worker'][:job_id]
  end

  def inject_instrumentation
    # Add the instrumentation again to ensure injection in server mode
    ::Sidekiq.configure_server do |cfg|
      cfg.server_middleware do |chain|
        chain.add ::Instana::Instrumentation::SidekiqWorker
      end
    end
  end

  class RedisFetcherMock
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
          "class":"SidekiqJobOne",
          "args":[1,2,3],
          "retry":false,
          "queue":"some_random_queue",
          "jid":"a79be9cabc60ceaa9a211437",
          "created_at":1499881322.1947122,
          "enqueued_at":1499881322.194849
        }
        JSON
      )
    end
  end

  class SidekiqManagerMock
    def processor_stopped(*args); end

    def options
      { fetch: RedisFetcherMock }
    end
  end
end
