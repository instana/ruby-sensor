# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2021

require 'test_helper'

class MongoTest < Minitest::Test
  def setup
    clear_all!
  end

  def teardown
    ::Instana.config[:allow_exit_as_root] = false
  end

  def test_mongo
    Instana.tracer.in_span(:'mongo-test') do
      client = Mongo::Client.new('mongodb://127.0.0.1:27017/instana')
      client[:people].delete_many({ name: /$S*/ })
      client[:people].insert_many([{ _id: 1, name: "Stan" }])
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

    client = Mongo::Client.new('mongodb://127.0.0.1:27017/instana')
    client[:people].delete_many({ name: /$S*/ })
    client[:people].insert_many([{ _id: 1, name: "Stan" }])

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
end
