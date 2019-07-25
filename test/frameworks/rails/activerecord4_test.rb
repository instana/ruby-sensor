require 'test_helper'
require 'active_record'

class ActiveRecordPgTest < Minitest::Test
  def test_config_defaults
    assert ::Instana.config[:active_record].is_a?(Hash)
    assert ::Instana.config[:active_record].key?(:enabled)
    assert_equal true, ::Instana.config[:active_record][:enabled]
  end

  def test_postgresql
    # Make one call to warm up the Rails stack and allow it to load
    # relations
    Net::HTTP.get(URI.parse('http://localhost:3205/test/db'))

    skip unless ::Instana::Test.postgresql?

    clear_all!

    Net::HTTP.get(URI.parse('http://localhost:3205/test/db'))

    traces = Instana.processor.queued_traces
    assert_equal 1, traces.length
    trace = traces.first

    assert_equal 6, trace.spans.length
    spans = trace.spans.to_a
    first_span = spans[0]
    second_span = spans[2]
    third_span = spans[3]
    fourth_span = spans[4]

    assert_equal :rack, first_span.name
    assert_equal :activerecord, second_span.name
    assert_equal :activerecord, third_span.name
    assert_equal :activerecord, fourth_span.name

    assert_equal "INSERT INTO \"blocks\" (\"name\", \"color\", \"created_at\", \"updated_at\") VALUES ($?, $?, $?, $?) RETURNING \"id\"", second_span[:data][:activerecord][:sql]
    assert_equal "SELECT  \"blocks\".* FROM \"blocks\" WHERE \"blocks\".\"name\" = $?  ORDER BY \"blocks\".\"id\" ASC LIMIT ?", third_span[:data][:activerecord][:sql]
    assert_equal "DELETE FROM \"blocks\" WHERE \"blocks\".\"id\" = $?", fourth_span[:data][:activerecord][:sql]

    assert_equal "postgresql", second_span[:data][:activerecord][:adapter]
    assert_equal "postgresql", third_span[:data][:activerecord][:adapter]
    assert_equal "postgresql", fourth_span[:data][:activerecord][:adapter]

    assert_equal ENV['TRAVIS_PSQL_HOST'], second_span[:data][:activerecord][:host]
    assert_equal ENV['TRAVIS_PSQL_HOST'], third_span[:data][:activerecord][:host]
    assert_equal ENV['TRAVIS_PSQL_HOST'], fourth_span[:data][:activerecord][:host]

    assert_equal "postgres", second_span[:data][:activerecord][:username]
    assert_equal "postgres", third_span[:data][:activerecord][:username]
    assert_equal "postgres", fourth_span[:data][:activerecord][:username]
  end

  def test_mysql2
    skip unless ::Instana::Test.mysql2?

    clear_all!

    Net::HTTP.get(URI.parse('http://localhost:3205/test/db'))

    traces = Instana.processor.queued_traces
    assert_equal 1, traces.length
    trace = traces.first

    assert_equal 6, trace.spans.length
    spans = trace.spans.to_a
    first_span = spans[0]
    second_span = spans[2]
    third_span = spans[3]
    fourth_span = spans[4]

    assert_equal :rack, first_span.name
    assert_equal :activerecord, second_span.name
    assert_equal :activerecord, third_span.name
    assert_equal :activerecord, fourth_span.name

    assert_equal "INSERT INTO `blocks` (`name`, `color`, `created_at`, `updated_at`) VALUES (?, ?, ?, ?)", second_span[:data][:activerecord][:sql]
    assert_equal "SELECT  `blocks`.* FROM `blocks` WHERE `blocks`.`name` = ?  ORDER BY `blocks`.`id` ASC LIMIT ?", third_span[:data][:activerecord][:sql]
    assert_equal "DELETE FROM `blocks` WHERE `blocks`.`id` = ?", fourth_span[:data][:activerecord][:sql]

    assert_equal "mysql2", second_span[:data][:activerecord][:adapter]
    assert_equal "mysql2", third_span[:data][:activerecord][:adapter]
    assert_equal "mysql2", fourth_span[:data][:activerecord][:adapter]

    assert_equal ENV['TRAVIS_MYSQL_HOST'], second_span[:data][:activerecord][:host]
    assert_equal ENV['TRAVIS_MYSQL_HOST'], third_span[:data][:activerecord][:host]
    assert_equal ENV['TRAVIS_MYSQL_HOST'], fourth_span[:data][:activerecord][:host]

    assert_equal ENV['TRAVIS_MYSQL_USER'], second_span[:data][:activerecord][:username]
    assert_equal ENV['TRAVIS_MYSQL_USER'], third_span[:data][:activerecord][:username]
    assert_equal ENV['TRAVIS_MYSQL_USER'], fourth_span[:data][:activerecord][:username]
  end

  def test_mysql
    skip unless ::Instana::Test.mysql?

    clear_all!

    Net::HTTP.get(URI.parse('http://localhost:3205/test/db'))

    traces = Instana.processor.queued_traces
    assert_equal 1, traces.length
    trace = traces.first

    assert_equal 6, trace.spans.length
    spans = trace.spans.to_a
    first_span = spans[0]
    second_span = spans[2]
    third_span = spans[3]
    fourth_span = spans[4]

    assert_equal :rack, first_span.name
    assert_equal :activerecord, second_span.name
    assert_equal :activerecord, third_span.name
    assert_equal :activerecord, fourth_span.name

    assert_equal "INSERT INTO `blocks` (`name`, `color`, `created_at`, `updated_at`) VALUES (?, ?, ?, ?)", second_span[:data][:activerecord][:sql]
    assert_equal "SELECT  `blocks`.* FROM `blocks` WHERE `blocks`.`name` = ?  ORDER BY `blocks`.`id` ASC LIMIT ?", third_span[:data][:activerecord][:sql]
    assert_equal "DELETE FROM `blocks` WHERE `blocks`.`id` = ?", fourth_span[:data][:activerecord][:sql]

    assert_equal "mysql", second_span[:data][:activerecord][:adapter]
    assert_equal "mysql", third_span[:data][:activerecord][:adapter]
    assert_equal "mysql", fourth_span[:data][:activerecord][:adapter]

    assert_equal ENV['TRAVIS_MYSQL_HOST'], second_span[:data][:activerecord][:host]
    assert_equal ENV['TRAVIS_MYSQL_HOST'], third_span[:data][:activerecord][:host]
    assert_equal ENV['TRAVIS_MYSQL_HOST'], fourth_span[:data][:activerecord][:host]

    assert_equal ENV['TRAVIS_MYSQL_USER'], second_span[:data][:activerecord][:username]
    assert_equal ENV['TRAVIS_MYSQL_USER'], third_span[:data][:activerecord][:username]
    assert_equal ENV['TRAVIS_MYSQL_USER'], fourth_span[:data][:activerecord][:username]
  end
end
