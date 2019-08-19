
require "instana/frameworks/instrumentation/mysql_adapter"
require "instana/frameworks/instrumentation/abstract_mysql_adapter"
require "instana/frameworks/instrumentation/mysql2_adapter"
require "instana/frameworks/instrumentation/postgresql_adapter"

if defined?(::ActiveRecord) && ::Instana.config[:active_record][:enabled]

  # Mysql
  if defined?(ActiveRecord::ConnectionAdapters::MysqlAdapter)
    ::Instana.logger.info "Instrumenting ActiveRecord (mysql)"
    ActiveRecord::ConnectionAdapters::MysqlAdapter.send(:include, ::Instana::Instrumentation::MysqlAdapter)
    ActiveRecord::ConnectionAdapters::AbstractMysqlAdapter.send(:include, ::Instana::Instrumentation::AbstractMysqlAdapter)
  end

  # Mysql2
  if defined?(ActiveRecord::ConnectionAdapters::Mysql2Adapter)
    ::Instana.logger.info "Instrumenting ActiveRecord (mysql2)"
    ActiveRecord::ConnectionAdapters::Mysql2Adapter.send(:include, ::Instana::Instrumentation::Mysql2Adapter)
  end

  # Postgres
  if defined?(ActiveRecord::ConnectionAdapters::PostgreSQLAdapter)
    ::Instana.logger.info "Instrumenting ActiveRecord (postgresql)"
    ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.send(:include, ::Instana::Instrumentation::PostgreSQLAdapter)
  end
end
