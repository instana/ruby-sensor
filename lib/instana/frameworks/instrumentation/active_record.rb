
require "instana/frameworks/instrumentation/mysql_adapter"
require "instana/frameworks/instrumentation/abstract_mysql_adapter"
require "instana/frameworks/instrumentation/mysql2_adapter"
require "instana/frameworks/instrumentation/postgresql_adapter"

if defined?(::ActiveRecord) && ::Instana.config[:active_record][:enabled]

  # Mysql
  if defined?(ActiveRecord::ConnectionAdapters::MysqlAdapter)
    ::Instana.logger.warn "Instrumenting ActiveRecord (mysql)"
    ActiveRecord::ConnectionAdapters::MysqlAdapter.send(:include, ::Instana::Instrumentation::MysqlAdapter)
    ActiveRecord::ConnectionAdapters::AbstractMysqlAdapter.send(:include, ::Instana::Instrumentation::AbstractMysqlAdapter)

  # Mysql2
  elsif defined?(ActiveRecord::ConnectionAdapters::Mysql2Adapter)
    ::Instana.logger.warn "Instrumenting ActiveRecord (mysql2)"
    ActiveRecord::ConnectionAdapters::Mysql2Adapter.send(:include, ::Instana::Instrumentation::Mysql2Adapter)

  # Postgres
  elsif defined?(ActiveRecord::ConnectionAdapters::PostgreSQLAdapter)
    ::Instana.logger.warn "Instrumenting ActiveRecord (postgresql)"
    ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.send(:include, ::Instana::Instrumentation::PostgreSQLAdapter)

  else
    ::Instana.logger.warn "Unsupported ActiveRecord adapter: #{ActiveRecord::Base.connection.adapter_name.downcase}"
  end
end
