# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2021

require 'test_helper'

class MongoTest < Minitest::Test
  def setup
    clear_all!
    @client = Mongo::Client.new('mongodb://127.0.0.1:27017/instana')
  end

  def teardown
    ::Instana.config[:allow_exit_as_root] = false
    @client.close
  end

  def test_mongo
    Instana.tracer.in_span(:'mongo-test') do
      @client[:people].delete_many({ name: /$S*/ })
      @client[:people].insert_many([{ _id: 1, name: "Stan" }])
    end

    spans = ::Instana.processor.queued_spans
    delete_span, insert_span, = spans

    delete_data = delete_span[:data][:mongo]
    insert_data = insert_span[:data][:mongo]

    assert_equal delete_span[:n], :mongo
    assert_equal insert_span[:n], :mongo

    assert_equal delete_data[:namespace], "instana"
    assert_equal delete_data[:command], "delete"
    assert_equal delete_data[:peer], {hostname: "127.0.0.1", port: 27017}
    assert delete_data[:json].include?("delete")

    assert_equal insert_data[:namespace], "instana"
    assert_equal insert_data[:command], "insert"
    assert_equal insert_data[:peer], {hostname: "127.0.0.1", port: 27017}
    assert insert_data[:json].include?("insert")
  end

  def test_mongo_as_root_exit_span
    ::Instana.config[:allow_exit_as_root] = true

    @client[:people].delete_many({ name: /$S*/ })
    @client[:people].insert_many([{ _id: 1, name: "Stan" }])

    spans = ::Instana.processor.queued_spans
    delete_span, insert_span, = spans

    delete_data = delete_span[:data][:mongo]
    insert_data = insert_span[:data][:mongo]

    assert_equal delete_span[:n], :mongo
    assert_equal insert_span[:n], :mongo

    assert_equal delete_data[:namespace], "instana"
    assert_equal delete_data[:command], "delete"
    assert_equal delete_data[:peer], {hostname: "127.0.0.1", port: 27017}
    assert delete_data[:json].include?("delete")

    assert_equal insert_data[:namespace], "instana"
    assert_equal insert_data[:command], "insert"
    assert_equal insert_data[:peer], {hostname: "127.0.0.1", port: 27017}
    assert insert_data[:json].include?("insert")
  end

  def test_mongo_no_error_is_raised_and_no_spans_are_created_when_agent_is_not_ready
    error = nil

    ::Instana.agent.stub(:ready?, false) do
      assert_silent do
        @client[:people].delete_many({ name: /$S*/ })
      rescue StandardError => e
        error = e
      end
    end

    assert_nil error
    assert_empty ::Instana.processor.queued_spans
  end

  def test_mongo_failed_event_records_error
    Instana.tracer.in_span(:'mongo-test') do
      # Use an invalid operation that the server will reject
      @client.database.command({ invalidCommand: 1 })
    rescue StandardError
      # expected
    end

    spans = ::Instana.processor.queued_spans
    mongo_span = find_first_span_by_name(spans, :mongo)
    refute_nil mongo_span, "Expected a :mongo span to be generated"

    assert_equal 1, mongo_span[:ec]
  end

  def test_mongo_filter_statement_removes_internal_keys
    ::Instana.config[:allow_exit_as_root] = true
    monitor = ::Instana::Mongo.new

    # Simulate a started event to exercise filter_statement via the public started method
    fake_event = Minitest::Mock.new
    fake_address = Minitest::Mock.new
    fake_address.expect(:host, '127.0.0.1')
    fake_address.expect(:port, 27017)

    fake_event.expect(:database_name, 'instana')
    fake_event.expect(:command_name, 'find')
    fake_event.expect(:address, fake_address)
    fake_event.expect(:address, fake_address)
    fake_event.expect(:request_id, 999)
    fake_event.expect(:command, { 'find' => 'people', 'lsid' => 'abc', '$db' => 'instana', 'documents' => [] })
    fake_event.expect(:request_id, 999)

    monitor.started(fake_event)
    # Finish the span so it is queued for assertions
    monitor.succeeded(fake_event)

    span = ::Instana.processor.queued_spans.find { |s| s[:n] == :mongo }
    refute_nil span, "Expected a :mongo span to be generated"

    json = span[:data][:mongo][:json]
    refute json.include?('lsid'), "lsid should be filtered from command"
    refute json.include?('$db'), "$db should be filtered from command"
    refute json.include?('documents'), "documents should be filtered from command"

    fake_event.verify
    fake_address.verify
  end
end
