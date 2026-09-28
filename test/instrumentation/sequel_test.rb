# (c) Copyright IBM Corp. 2024

require 'test_helper'
require 'sequel'

class SequelTest < Minitest::Test
  def setup
    skip unless ENV['DATABASE_URL']
    db_url = ENV['DATABASE_URL'].sub("sqlite3", "sqlite")
    @db = Sequel.connect(db_url)
    @db.create_table!(:blocks) do
      String :name
      String :color
    end
    @model = @db[:blocks]
  end

  def teardown
    @db.drop_table(:blocks)
    @db.disconnect
  end

  def test_config_defaults
    assert ::Instana.config[:sanitize_sql] == true
    assert ::Instana.config[:sequel].is_a?(Hash)
    assert ::Instana.config[:sequel].key?(:enabled)
    assert_equal true, ::Instana.config[:sequel][:enabled]
  end

  def test_create
    clear_all!
    Instana.tracer.in_span(:sequel_test, attributes: {}) do
      @model.insert(name: 'core', color: 'blue')
    end
    spans = ::Instana.processor.queued_spans
    assert_equal 2, spans.length
    span = find_first_span_by_name(spans, :sequel)
    data = span[:data][:sequel]
    assert data[:sql].start_with?('INSERT INTO')
  end

  def test_read
    clear_all!
    @model.insert(name: 'core', color: 'blue')
    Instana.tracer.in_span(:sequel_test, attributes: {}) do
      @model.where(name: 'core').first
    end
    spans = ::Instana.processor.queued_spans
    assert_equal 2, spans.length
    span = find_first_span_by_name(spans, :sequel)
    data = span[:data][:sequel]
    assert data[:sql].start_with?('SELECT')
    assert_nil span[:ec]
  end

  def test_update
    clear_all!
    @model.insert(name: 'core', color: 'blue')
    Instana.tracer.in_span(:sequel_test, attributes: {}) do
      @model.where(name: 'core').update(color: 'red')
    end
    spans = ::Instana.processor.queued_spans
    assert_equal 2, spans.length
    span = find_first_span_by_name(spans, :sequel)
    data = span[:data][:sequel]
    assert data[:sql].start_with?('UPDATE')
    assert_nil span[:ec]
    assert_equal 'red', @model.where(name: 'core').first[:color]
  end

  def test_delete
    clear_all!
    @model.insert(name: 'core', color: 'blue')
    Instana.tracer.in_span(:sequel_test, attributes: {}) do
      @model.where(name: 'core').delete
    end
    spans = ::Instana.processor.queued_spans
    assert_equal 2, spans.length
    span = find_first_span_by_name(spans, :sequel)
    data = span[:data][:sequel]
    assert data[:sql].start_with?('DELETE')
    assert_nil span[:ec]
    assert_nil @model.where(name: 'core').first
  end

  def test_raw
    clear_all!
    Instana.tracer.in_span(:sequel_test, attributes: {}) do
      @db.run('SELECT 1')
    end
    spans = ::Instana.processor.queued_spans
    assert_equal 2, spans.length
    span = find_first_span_by_name(spans, :sequel)
    data = span[:data][:sequel]
    assert 'SELECT 1', data[:sql]
    assert_nil span[:ec]
  end

  def test_raw_error
    clear_all!
    assert_raises Sequel::DatabaseError do
      Instana.tracer.in_span(:sequel_test, attributes: {}) do
        @db.run('INVALID')
      end
    end
    spans = ::Instana.processor.queued_spans
    assert_equal 2, spans.length
    span = find_first_span_by_name(spans, :sequel)
    assert_equal 1, span[:ec]
  end

  def test_no_error_is_raised_and_no_spans_are_created_when_agent_is_not_ready
    skip unless ENV['DATABASE_URL']
    clear_all!
    error = nil

    ::Instana.agent.stub(:ready?, false) do
      assert_silent do
        @model.insert(name: 'test', color: 'blue')
      rescue StandardError => e
        error = e
      end
    end

    assert_nil error
    assert_empty ::Instana.processor.queued_spans
  end

  def test_sanitize_sql_disabled_keeps_raw_values
    original = ::Instana.config[:sanitize_sql]
    ::Instana.config[:sanitize_sql] = false
    clear_all!

    Instana.tracer.in_span(:sequel_test) do
      @model.insert(name: 'plaintext_value', color: 'blue')
    end

    spans = ::Instana.processor.queued_spans
    span = find_first_span_by_name(spans, :sequel)
    data = span[:data][:sequel]

    assert data[:sql].include?('plaintext_value'), "Raw value should appear in SQL when sanitize_sql is false"
  ensure
    ::Instana.config[:sanitize_sql] = original
  end

  def test_pragma_queries_are_ignored
    clear_all!

    Instana.tracer.in_span(:sequel_test) do
      # PRAGMA is on the ignored list for Sequel
      begin
        @db.run('PRAGMA table_info(blocks)')
      rescue StandardError
        nil # sqlite3 adapter may not accept this form via run
      end
      @db.send(:log_connection_yield, 'PRAGMA table_info(blocks)', nil) { nil }
    end

    spans = ::Instana.processor.queued_spans
    sequel_span = find_first_span_by_name(spans, :sequel)
    assert_nil sequel_span, "PRAGMA queries should not be traced"
  end

  def test_version_select_is_ignored
    clear_all!

    Instana.tracer.in_span(:sequel_test) do
      @db.send(:log_connection_yield, 'SELECT VERSION()', nil) { nil }
    end

    spans = ::Instana.processor.queued_spans
    sequel_span = find_first_span_by_name(spans, :sequel)
    assert_nil sequel_span, "SELECT VERSION() should not be traced"
  end

  def test_not_tracing_skips_span
    clear_all!

    @model.insert(name: 'no_trace', color: 'green')

    spans = ::Instana.processor.queued_spans
    sequel_span = find_first_span_by_name(spans, :sequel)
    assert_nil sequel_span, "No sequel span should be created outside an active trace"
  end

  def test_begin_commit_ignored_by_sequel
    clear_all!

    Instana.tracer.in_span(:sequel_test) do
      @db.send(:log_connection_yield, 'BEGIN', nil) { nil }
      @db.send(:log_connection_yield, 'COMMIT', nil) { nil }
    end

    spans = ::Instana.processor.queued_spans
    sequel_span = find_first_span_by_name(spans, :sequel)
    assert_nil sequel_span, "BEGIN/COMMIT should not be traced by Sequel instrumentation"
  end
end
