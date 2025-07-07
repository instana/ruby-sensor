# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2021

require 'test_helper'
require 'support/apps/active_record/active_record'

class RailsActiveRecordTest < Minitest::Test
  def setup
    clear_all!
    skip unless ENV['DATABASE_URL']
    @connection = ActiveRecord::Base.establish_connection(ENV['DATABASE_URL'])
    ActiveRecord::Migration.suppress_messages do
      ActiveRecord::Migration.run(CreateBlocks, direction: :up)
    end
  end

  def teardown
    ActiveRecord::Migration.suppress_messages do
      ActiveRecord::Migration.run(CreateBlocks, direction: :down)
    end
    ActiveRecord::Base.remove_connection
  end

  def test_config_defaults
    assert ::Instana.config[:sanitize_sql] == true
    assert ::Instana.config[:active_record].is_a?(Hash)
    assert ::Instana.config[:active_record].key?(:enabled)
    assert_equal true, ::Instana.config[:active_record][:enabled]
  end

  def test_create
    # clear_all!
    Instana.tracer.in_span(:ar_test, attributes: {}) do
      Block.create(name: 'core', color: 'blue')
    end

    spans = ::Instana.processor.queued_spans
    assert_equal 2, spans.length
    span = find_first_span_by_name(spans, :activerecord)
    data = span[:data][:activerecord]

    assert data[:sql].start_with?('INSERT INTO')
  end

  def test_read
    Block.create(name: 'core', color: 'blue')
    Instana.tracer.in_span(:ar_test, attributes: {}) do
      Block.find_by(name: 'core')
    end
    spans = ::Instana.processor.queued_spans
    assert_equal 2, spans.length
    span = find_first_span_by_name(spans, :activerecord)
    data = span[:data][:activerecord]

    assert data[:sql].start_with?('SELECT')
  end

  def test_update
    Block.create(name: 'core', color: 'blue')
    b = Block.find_by(name: 'core')

    Instana.tracer.in_span(:ar_test, attributes: {}) do
      b.color = 'red'
      b.save
    end

    spans = ::Instana.processor.queued_spans
    assert_equal 2, spans.length
    span = find_first_span_by_name(spans, :activerecord)
    data = span[:data][:activerecord]

    assert data[:sql].start_with?('UPDATE')
  end

  def test_delete
    b = Block.create(name: 'core', color: 'blue')

    Instana.tracer.in_span(:ar_test, attributes: {}) do
      b.delete
    end

    spans = ::Instana.processor.queued_spans
    assert_equal 2, spans.length
    span = find_first_span_by_name(spans, :activerecord)
    data = span[:data][:activerecord]

    assert data[:sql].start_with?('DELETE')
  end

  def test_raw
    Instana.tracer.in_span(:ar_test, attributes: {}) do
      ActiveRecord::Base.connection.execute('SELECT 1')
    end

    spans = ::Instana.processor.queued_spans
    assert_equal 2, spans.length
    span = find_first_span_by_name(spans, :activerecord)
    data = span[:data][:activerecord]

    assert 'SELECT 1', data[:sql]
  end

  def test_raw_error
    assert_raises ActiveRecord::StatementInvalid do
      Instana.tracer.in_span(:ar_test, attributes: {}) do
        ActiveRecord::Base.connection.execute('INVALID')
      end
    end

    spans = ::Instana.processor.queued_spans
    assert_equal 2, spans.length
    span = find_first_span_by_name(spans, :activerecord)

    assert_equal 1, span[:ec]
  end
end
