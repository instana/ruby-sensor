require 'test_helper'
require 'active_record'

class ActiveRecordTest < Minitest::Test
  def test_config_defaults
    assert ::Instana.config[:active_record].is_a?(Hash)
    assert ::Instana.config[:active_record].key?(:enabled)
    assert_equal true, ::Instana.config[:active_record][:enabled]
  end

  def test_postgresql
    skip unless ::Instana::Test.postgresql?

    clear_all!

    Net::HTTP.get(URI.parse('http://localhost:3205/test/db'))

    spans = Instana.processor.queued_spans
    assert_equal 6, spans.length
    rack_span = find_first_span_by_name(spans, :rack)

    ar_spans = find_spans_by_name(spans, :activerecord)
    assert_equal 3, ar_spans.length

    ar_spans.each do |span|
      assert_equal "postgresql", span[:data][:activerecord][:adapter]
      assert span[:data][:activerecord].key?(:host)
      assert span[:data][:activerecord].key?(:username)
    end


    found = false
    if ::Rails::VERSION::MAJOR < 4
      sql = "INSERT INTO \"blocks\" (\"color\", \"created_at\", \"name\", \"updated_at\") VALUES ($?, $?, $?, $?) RETURNING \"id\""
    else
      sql = "INSERT INTO \"blocks\" (\"name\", \"color\", \"created_at\", \"updated_at\") VALUES ($?, $?, $?, $?) RETURNING \"id\""
    end
    ar_spans.each do |span|
      if span[:data][:activerecord][:sql] ==
        found = true
      end
    end
    assert found

    found = false
    if ::Rails::VERSION::MAJOR >= 5
      sql = "SELECT  \"blocks\".* FROM \"blocks\" WHERE \"blocks\".\"name\" = $? ORDER BY \"blocks\".\"id\" ASC LIMIT $?"
    elsif ::Rails::VERSION::MAJOR == 4
      sql = "SELECT  \"blocks\".* FROM \"blocks\" WHERE \"blocks\".\"name\" = $?  ORDER BY \"blocks\".\"id\" ASC LIMIT ?"
    else
      sql = "SELECT  \"blocks\".* FROM \"blocks\"  WHERE \"blocks\".\"name\" = ? LIMIT ?"
    end
    ar_spans.each do |span|
      if span[:data][:activerecord][:sql] == sql
        found = true
      end
    end
    assert found

    found = false
    if ::Rails::VERSION::MAJOR == 3
      sql = "DELETE FROM \"blocks\" WHERE \"blocks\".\"id\" = ?"
    else
      sql = "DELETE FROM \"blocks\" WHERE \"blocks\".\"id\" = $?"
    end
    ar_spans.each do |span|
      if span[:data][:activerecord][:sql] == sql
        found = true
      end
    end
    assert found
  end

  def test_postgresql_lock_table
    skip unless ::Instana::Test.postgresql?

    clear_all!

    Net::HTTP.get(URI.parse('http://localhost:3205/test/db_lock_table'))

    spans = Instana.processor.queued_spans
    assert_equal 5, spans.length

    rack_span = find_first_span_by_name(spans, :rack)
    ac_span = find_first_span_by_name(spans, :actioncontroller)
    av_span = find_first_span_by_name(spans, :actionview)

    ar_spans = find_spans_by_name(spans, :activerecord)
    assert_equal 2, ar_spans.length

    ar_spans.each do |ar_span|
      assert_equal "postgresql", ar_span[:data][:activerecord][:adapter]
      assert_equal "postgres", ar_span[:data][:activerecord][:username]
    end

    found = false
    ar_spans.each do |span|
      if span[:data][:activerecord][:sql] == "LOCK blocks IN ACCESS EXCLUSIVE MODE"
        found = true
      end
    end
    assert found

    found = false
    ar_spans.each do |span|
      if span[:data][:activerecord][:sql] == "SELECT ?"
        found = true
      end
    end
    assert found
  end

  def test_postgresql_raw_execute
    skip unless ::Instana::Test.postgresql?

    clear_all!

    Net::HTTP.get(URI.parse('http://localhost:3205/test/db_raw_execute'))

    spans = Instana.processor.queued_spans

    assert_equal 4, spans.length
    rack_span = find_first_span_by_name(spans, :rack)
    ac_span = find_first_span_by_name(spans, :actioncontroller)
    av_span = find_first_span_by_name(spans, :actionview)
    ar_span = find_first_span_by_name(spans, :activerecord)

    assert_equal "SELECT ?", ar_span[:data][:activerecord][:sql]
    assert_equal "postgresql", ar_span[:data][:activerecord][:adapter]
    assert_equal "postgres", ar_span[:data][:activerecord][:username]
  end

  def test_postgresql_raw_execute_error
    skip unless ::Instana::Test.postgresql?

    clear_all!

    Net::HTTP.get(URI.parse('http://localhost:3205/test/db_raw_execute_error'))

    spans = Instana.processor.queued_spans

    assert_equal 3, spans.length
    rack_span = find_first_span_by_name(spans, :rack)
    ac_span = find_first_span_by_name(spans, :actioncontroller)
    ar_span = find_first_span_by_name(spans, :activerecord)

    assert ar_span.key?(:stack)
    assert ar_span[:data][:activerecord].key?(:error)
    assert ar_span[:data][:activerecord][:error].include?("syntax error")
    assert_equal "This is not real SQL but an intended error", ar_span[:data][:activerecord][:sql]
    assert_equal "postgresql", ar_span[:data][:activerecord][:adapter]
    assert_equal "postgres", ar_span[:data][:activerecord][:username]
  end

  def test_mysql2
    skip unless ::Instana::Test.mysql2?

    clear_all!

    Net::HTTP.get(URI.parse('http://localhost:3205/test/db'))

    spans = Instana.processor.queued_spans
    assert_equal 6, spans.length
    rack_span = find_first_span_by_name(spans, :rack)

    ar_spans = find_spans_by_name(spans, :activerecord)
    assert_equal 3, ar_spans.length

    ar_spans.each do |span|
      assert_equal "mysql2", span[:data][:activerecord][:adapter]
      assert span[:data][:activerecord].key?(:host)
      assert span[:data][:activerecord].key?(:username)
    end

    queries = [
        "INSERT INTO `blocks` (`name`, `color`, `created_at`, `updated_at`) VALUES (?, ?, ?, ?)",
        "SELECT  `blocks`.* FROM `blocks` WHERE `blocks`.`name` = ?  ORDER BY `blocks`.`id` ASC LIMIT ?",
        "DELETE FROM `blocks` WHERE `blocks`.`id` = ?"
    ]

    queries.each do |sql|
      found = false
      ar_spans.each do |span|
        if span[:data][:activerecord][:sql] = sql
          found = true
        end
      end
      assert found
    end
  end

  def test_mysql
    skip unless ::Instana::Test.mysql?

    clear_all!

    Net::HTTP.get(URI.parse('http://localhost:3205/test/db'))

    spans = Instana.processor.queued_spans
    assert_equal 6, spans.length
    first_span = spans[0]
    second_span = spans[2]
    third_span = spans[3]
    fourth_span = spans[4]

    assert_equal :rack, first_span[:n]
    assert_equal :activerecord, second_span[:n]
    assert_equal :activerecord, third_span[:n]
    assert_equal :activerecord, fourth_span[:n]

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
