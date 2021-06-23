# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2021

require 'test_helper'
require 'support/apps/active_record/active_record'
require 'fileutils'

class RailsActiveRecordDatabaseMissingTest < Minitest::Test
  def setup
    skip unless ENV['DATABASE_URL']

    @old_url = ENV['DATABASE_URL']
    SQLite3::Database.new('/tmp/test.db')
    ENV['DATABASE_URL'] = 'sqlite3:///tmp/test.db'

    @connection = ActiveRecord::Base.establish_connection(ENV['DATABASE_URL'])
    ActiveRecord::Migration.suppress_messages do
      ActiveRecord::Migration.run(CreateBlocks, direction: :up)
    end
  end

  def teardown
    ActiveRecord::Base.remove_connection(@connection)
    ENV['DATABASE_URL'] = @old_url
  end

  def test_error_on_missing_database
    assert_raises(ActiveRecord::StatementInvalid) do
      Instana::Tracer.start_or_continue_trace(:ar_test, {}) do
        b = Block.new
        FileUtils.rm('/tmp/test.db')
        b.save!
      end
    end

    spans = ::Instana.processor.queued_spans
    assert_equal 3, spans.length
    span = find_first_span_by_name(spans, :activerecord)

    assert_equal 1, span[:ec]
    assert span[:data][:activerecord][:error].include?("SQLite3::ReadOnlyException: attempt to write a readonly database")
  end
end
