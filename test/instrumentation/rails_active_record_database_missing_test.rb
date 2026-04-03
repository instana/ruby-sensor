# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2021

require 'test_helper'
require 'support/apps/active_record/active_record'
require 'fileutils'

class RailsActiveRecordDatabaseMissingTest < Minitest::Test
  def setup
    skip unless ENV['DATABASE_URL']
    clear_all!
    @old_url = ENV['DATABASE_URL']
    SQLite3::Database.new('/tmp/test.db')
    ENV['DATABASE_URL'] = 'sqlite3:///tmp/test.db'

    @connection_pool = ActiveRecord::Base.establish_connection(ENV['DATABASE_URL'])
    c = ::ActiveRecord::Base.connection
    c.execute 'PRAGMA journal_mode=DELETE'
    c.execute 'PRAGMA locking_mode=NORMAL'
    ActiveRecord::Migration.suppress_messages do
      ActiveRecord::Migration.run(CreateBlocks, direction: :up)
    end
  end

  def teardown
    @connection_pool.disconnect
    ENV['DATABASE_URL'] = @old_url
  end

  def test_error_on_missing_database
    assert_raises(ActiveRecord::StatementInvalid) do
      Instana.tracer.in_span(:ar_test, attributes: {}) do
        b = Block.new
        FileUtils.rm('/tmp/test.db')
        b.save!
      end
    end
    spans = ::Instana.processor.queued_spans
    span = find_first_span_by_name(spans, :activerecord)

    assert_equal 1, span[:ec]
    assert span[:data][:activerecord][:error].include?("SQLite3::ReadOnlyException: attempt to write a readonly database")
  end

  def test_no_error_is_raised_and_no_spans_are_created_when_agent_is_not_ready
    skip unless ENV['DATABASE_URL']
    clear_all!
    error = nil

    ::Instana.agent.stub(:ready?, false) do
      assert_silent do
        Block.create(name: 'test', color: 'green')
      rescue StandardError => e
        error = e
      end
    end

    assert_nil error
    assert_empty ::Instana.processor.queued_spans
  end
end
