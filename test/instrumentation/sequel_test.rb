# (c) Copyright IBM Corp. 2024
# (c) Copyright Instana Inc. 2024
require 'test_helper'
require 'sequel'
Sequel.extension :migration

class SequelTest < Minitest::Test
  def setup
    skip unless ENV['DATABASE_URL']
    @db = Sequel.connect(ENV['DATABASE_URL'])

    DummyMigration.apply(@db, :up)
    @model = @db[:blocks]
  end

  def teardown
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
    Instana::Tracer.start_or_continue_trace(:ar_test, {}) do
      @model.find(name: 'core')
    end

    spans = ::Instana.processor.queued_spans
    assert_equal 2, spans.length
    span = find_first_span_by_name(spans, :sequel)
    data = span[:data][:sequel]
    assert data[:sql].start_with?('SELECT')
  end

  def test_update
    @model.insert(name: 'core', color: 'blue')
    b = @model.find(name: 'core')

    Instana::Tracer.start_or_continue_trace(:sequel_test, {}) do
      b.color = 'red'
      b.save
    end

    spans = ::Instana.processor.queued_spans
    assert_equal 2, spans.length
    span = find_first_span_by_name(spans, :sequel)
    data = span[:data][:sequel]
    assert data[:sql].start_with?('UPDATE')
  end

  def test_delete
    b = @model.insert(name: 'core', color: 'blue')

    Instana::Tracer.start_or_continue_trace(:sequel_test, {}) do
      b.delete
    end

    spans = ::Instana.processor.queued_spans
    assert_equal 2, spans.length
    span = find_first_span_by_name(spans, :sequel)
    data = span[:data][:sequel]
    assert data[:sql].start_with?('DELETE')
  end

  def test_raw
    Instana::Tracer.start_or_continue_trace(:sequel_test, {}) do
      @db.execute('SELECT 1')
    end

    spans = ::Instana.processor.queued_spans
    assert_equal 2, spans.length
    span = find_first_span_by_name(spans, :sequel)
    data = span[:data][:sequel]
    assert 'SELECT 1', data[:sql]
  end

  def test_raw_error
    assert_raises Sequel::DatabaseError do
      Instana::Tracer.start_or_continue_trace(:sequel_test, {}) do
        @db.execute('INVALID')
      end
    end

    spans = ::Instana.processor.queued_spans
    assert_equal 2, spans.length
    span = find_first_span_by_name(spans, :sequel)

    assert_equal 1, span[:ec]
  end

end

class DummyMigration < Sequel::Migration
  def up
    create_table! (:blocks) do
      String :name
      String :color
    end
  end
end
