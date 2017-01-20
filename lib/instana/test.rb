module Instana
  class Test
    class << self
      # Used at the start of the test suite to configure required environment
      # variables (if missing)
      #
      def setup_environment
        # Set defaults if not set
        ENV['MEMCACHED_HOST']     ||= '127.0.0.1:11211'
        ENV['TRAVIS_PSQL_HOST']   ||= "127.0.0.1"
        ENV['TRAVIS_PSQL_USER']   ||= "postgres"
        ENV['TRAVIS_MYSQL_HOST']  ||= "127.0.0.1"
        ENV['TRAVIS_MYSQL_USER']  ||= "root"

        if ENV['DB_FLAVOR'] == 'mysql2'
          ENV['DATABASE_URL'] = "mysql2://#{ENV['TRAVIS_MYSQL_USER']}:#{ENV['TRAVIS_MYSQL_PASS']}@#{ENV['TRAVIS_MYSQL_HOST']}:3306/travis_ci_test"
        else
          ENV['DATABASE_URL'] = "postgresql://#{ENV['TRAVIS_PSQL_USER']}:#{ENV['TRAVIS_PSQL_PASS']}@#{ENV['TRAVIS_PSQL_HOST']}:5432/travis_ci_test"
        end

        Instana.logger.warn "Database connect string configured to: #{ENV['DATABASE_URL']}"
      end
    end
  end
end
