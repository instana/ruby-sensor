module Instana
  class Test
    class << self
      # Used at the start of the test suite to configure required environment
      # variables (if missing)
      #
      def setup_environment
        # Set defaults if not set
        ENV['MEMCACHED_HOST']     ||= '127.0.0.1:11211'
        ENV['POSTGRES_HOST']      ||= "127.0.0.1"
        ENV['POSTGRES_USER']      ||= "stan"
        ENV['POSTGRES_PASSWORD']  ||= "stanlikesdata"
        ENV['TRAVIS_MYSQL_HOST']  ||= "127.0.0.1"
        ENV['TRAVIS_MYSQL_USER']  ||= "root"

        if !ENV.key?('DATABASE_URL')
          if ENV['DB_FLAVOR'] == 'postgresql'
            ENV['DATABASE_URL'] = "postgresql://#{ENV['POSTGRES_USER']}:#{ENV['POSTGRES_PASSWORD']}@#{ENV['POSTGRES_HOST']}:5432/#{ENV['POSTGRES_USER']}"
          elsif ENV['DB_FLAVOR'] == 'mysql'
            ENV['DATABASE_URL'] = "mysql://#{ENV['TRAVIS_MYSQL_USER']}:#{ENV['TRAVIS_MYSQL_PASS']}@#{ENV['TRAVIS_MYSQL_HOST']}:3306/travis_ci_test"
          else
            ENV['DB_FLAVOR'] ||= 'mysql2'
            ENV['DATABASE_URL'] = "mysql2://#{ENV['TRAVIS_MYSQL_USER']}:#{ENV['TRAVIS_MYSQL_PASS']}@#{ENV['TRAVIS_MYSQL_HOST']}:3306/travis_ci_test"
          end
        end

        Instana.logger.warn "Database connect string configured to: #{ENV['DATABASE_URL']}"
      end

      def postgresql?
        ENV['DB_FLAVOR'] == 'postgresql'
      end

      def mysql2?
        ENV['DB_FLAVOR'] == 'mysql2'
      end

      def mysql?
        ENV['DB_FLAVOR'] == 'mysql'
      end
    end
  end
end
