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
    Instana::Tracer.start_or_continue_trace(:sequel_test, {}) do
      @model.insert(name: 'core', color: 'blue')
    end
    spans = ::Instana.processor.queued_spans
    assert_equal 2, spans.length
    span = find_first_span_by_name(spans, :sequel)
    data = span[:data][:sequel]
    assert data[:sql].start_with?('INSERT INTO')
  end

  def test_read
    @model.insert(name: 'core', color: 'blue')
    Instana::Tracer.start_or_continue_trace(:sequel_test, {}) do
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
    @model.insert(name: 'core', color: 'blue')
    Instana::Tracer.start_or_continue_trace(:sequel_test, {}) do
      @model.where(name: 'core').update(color: 'red')
    end
    spans = ::Instana.processor.queued_spans
    assert_equal 2, spans.length
    span = find_first_span_by_name(spans, :sequel)
    data = span[:data][:sequel]
    assert data[:sql].start_with?('UPDATE')
    assert_nil span[:ec]
  end

  def test_delete
    @model.insert(name: 'core', color: 'blue')
    Instana::Tracer.start_or_continue_trace(:sequel_test, {}) do
      @model.where(name: 'core').delete
    end
    spans = ::Instana.processor.queued_spans
    assert_equal 2, spans.length
    span = find_first_span_by_name(spans, :sequel)
    data = span[:data][:sequel]
    assert data[:sql].start_with?('DELETE')
    assert_nil span[:ec]
  end

  def test_raw
    Instana::Tracer.start_or_continue_trace(:sequel_test, {}) do
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
    assert_raises Sequel::DatabaseError do
      Instana::Tracer.start_or_continue_trace(:sequel_test, {}) do
        @db.run('INVALID')
      end
    end
    spans = ::Instana.processor.queued_spans
    assert_equal 2, spans.length
    span = find_first_span_by_name(spans, :sequel)

    assert_equal 1, span[:ec]
  end
end
