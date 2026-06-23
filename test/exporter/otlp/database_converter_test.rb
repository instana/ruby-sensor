# (c) Copyright IBM Corp. 2026

require 'test_helper'
require 'instana/exporter/otlp/database_converter'

class DatabaseConverterTest < Minitest::Test
  def test_activerecord_conversion
    span = create_span(:activerecord, {
      activerecord: { adapter: 'postgresql', db: 'mydb', sql: 'SELECT * FROM users', username: 'admin', host: 'db.example.com' }
    })
    converter = Instana::Exporter::Otlp::DatabaseConverter.new(span)
    attrs = converter.send(:convert_attributes)

    assert_equal 'postgresql', attrs['db.system.name']
    assert_equal 'mydb', attrs['db.namespace']
    assert_equal 'SELECT * FROM users', attrs['db.query.text']
    assert_equal 'admin', attrs['db.user']
    assert_equal 'db.example.com', attrs['server.address']
  end

  def test_sequel_conversion
    span = create_span(:sequel, {
      sequel: { adapter: 'mysql2', db: 'testdb', sql: 'INSERT INTO logs', username: 'root', host: 'localhost' }
    })
    converter = Instana::Exporter::Otlp::DatabaseConverter.new(span)
    attrs = converter.send(:convert_attributes)

    assert_equal 'mysql2', attrs['db.system.name']
    assert_equal 'testdb', attrs['db.namespace']
    assert_equal 'INSERT INTO logs', attrs['db.query.text']
    assert_equal 'root', attrs['db.user']
    assert_equal 'localhost', attrs['server.address']
  end

  def test_redis_conversion
    span = create_span(:redis, {
      redis: { command: 'GET key', db: 2, connection: 'redis.local:6379' }
    })
    converter = Instana::Exporter::Otlp::DatabaseConverter.new(span)
    attrs = converter.send(:convert_attributes)

    assert_equal 'redis', attrs['db.system.name']
    assert_equal 'GET key', attrs['db.query.text']
    assert_equal 2, attrs['db.redis.database_index']
    assert_equal 'redis.local', attrs['server.address']
    assert_equal 6379, attrs['server.port']
  end

  def test_memcache_conversion
    span = create_span(:memcache, {
      memcache: { command: 'get', key: 'user:123', namespace: 'app', server: '127.0.0.1:11211' }
    })
    converter = Instana::Exporter::Otlp::DatabaseConverter.new(span)
    attrs = converter.send(:convert_attributes)

    assert_equal 'memcached', attrs['db.system.name']
    assert_equal 'get', attrs['db.operation.name']
    assert_equal 'user:123', attrs['db.memcached.key']
    assert_equal 'app', attrs['db.memcached.namespace']
    assert_equal '127.0.0.1', attrs['server.address']
    assert_equal 11211, attrs['server.port']
  end

  def test_memcache_with_keys
    span = create_span(:memcache, {
      memcache: { command: 'get_multi', keys: ['key1', 'key2'], server: 'localhost:11211' }
    })
    converter = Instana::Exporter::Otlp::DatabaseConverter.new(span)
    attrs = converter.send(:convert_attributes)

    assert_equal ['key1', 'key2'], attrs['db.memcached.keys']
  end

  def test_mongodb_conversion
    span = create_span(:mongo, {
      mongo: { namespace: 'mydb.users', command: 'find', json: '{"name":"John"}', peer: { hostname: 'mongo.local', port: 27017 } }
    })
    converter = Instana::Exporter::Otlp::DatabaseConverter.new(span)
    attrs = converter.send(:convert_attributes)

    assert_equal 'mongodb', attrs['db.system.name']
    assert_equal 'mydb.users', attrs['db.namespace']
    assert_equal 'find', attrs['db.operation.name']
    assert_equal '{"name":"John"}', attrs['db.query.text']
    assert_equal 'mongo.local', attrs['server.address']
    assert_equal 27017, attrs['server.port']
  end

  def test_extract_host
    span = create_span(:redis, {})
    converter = Instana::Exporter::Otlp::DatabaseConverter.new(span)

    assert_equal 'localhost', converter.send(:extract_host, 'localhost:6379')
    assert_equal 'redis.local', converter.send(:extract_host, 'redis.local:6380')
    assert_nil converter.send(:extract_host, nil)
  end

  def test_extract_port
    span = create_span(:redis, {})
    converter = Instana::Exporter::Otlp::DatabaseConverter.new(span)

    assert_equal 6379, converter.send(:extract_port, 'localhost:6379')
    assert_equal 11211, converter.send(:extract_port, '127.0.0.1:11211')
    assert_nil converter.send(:extract_port, 'invalid')
    assert_nil converter.send(:extract_port, nil)
  end

  def test_missing_data
    span = create_span(:activerecord, {})
    converter = Instana::Exporter::Otlp::DatabaseConverter.new(span)
    attrs = converter.send(:convert_attributes)

    assert_empty attrs
  end

  private

  def create_span(name, data)
    span = Instana::Span.new(name)
    span[:data] = data
    span.close
    span
  end
end
