module Instana
  module Util
    class << self
      # An agnostic approach to method aliasing.
      #
      # @param klass [Object] The class or module that holds the method to be alias'd.
      # @param method [Symbol] The name of the method to be aliased.
      #
      def method_alias(klass, method)
        if klass.method_defined?(method.to_sym)

          with = "#{method}_with_instana"
          without = "#{method}_without_instana"

          klass.class_eval do
            alias_method without, method.to_s
            alias_method method.to_s, with
          end
        else
          ::Instana.logger.debug "No such method (#{method}) to alias on #{klass}"
        end
      end

      # Take two hashes, and make sure candidate does not have
      # any of the same values as `last`.  We only report
      # when values change.
      #
      # Note this is not recursive, so only pass in the single
      # hashes that you want delta reporting with.
      #
      def enforce_deltas(candidate, last)
        return unless last.is_a?(Hash)

        candidate.each do |k,v|
          if candidate[k] == last[k]
            candidate.delete(k)
          end
        end
        candidate
      end

      # Debugging helper method
      #
      def pry!
        # Only valid for development or test environments
        #env = ENV['RACK_ENV'] || ENV['RAILS_ENV']
        #return unless %w(development, test).include? env

        if RUBY_VERSION > '1.8.7'
          require 'pry-byebug'

          if defined?(PryByebug)
            Pry.commands.alias_command 'c', 'continue'
            Pry.commands.alias_command 's', 'step'
            Pry.commands.alias_command 'n', 'next'
            Pry.commands.alias_command 'f', 'finish'

            Pry::Commands.command(/^$/, 'repeat last command') do
              _pry_.run_command Pry.history.to_a.last
            end
          end

          binding.pry
        else
          require 'ruby-debug'; debugger
        end
      end

      # Retrieves and returns the source code for any ruby
      # files requested by the UI via the host agent
      #
      # @param file [String] The fully qualified path to a file
      #
      def get_rb_source(file)
        if (file =~ /.rb$/).nil?
          { :error => "Only Ruby source files are allowed. (*.rb)" }
        else
          { :data => File.read(file) }
        end
      rescue => e
        return { :error => e.inspect }
      end

      # Method to collect up process info for snapshots.  This
      # is generally used once per process.
      #
      def take_snapshot
        data = {}

        data[:sensorVersion] = ::Instana::VERSION
        data[:ruby_version] = RUBY_VERSION

        # Since a snapshot is only taken on process boot,
        # this is ok here.
        data[:start_time] = Time.now.to_s

        # Framework Detection
        if defined?(::RailsLts::VERSION)
          data[:framework] = "Rails on Rails LTS-#{::RailsLts::VERSION}"

        elsif defined?(::Rails.version)
          data[:framework] = "Ruby on Rails #{::Rails.version}"

        elsif defined?(::Grape::VERSION)
          data[:framework] = "Grape #{::Grape::VERSION}"

        elsif defined?(::Padrino::VERSION)
          data[:framework] = "Padrino #{::Padrino::VERSION}"

        elsif defined?(::Sinatra::VERSION)
          data[:framework] = "Sinatra #{::Sinatra::VERSION}"
        end

        # Report Bundle
        if defined?(::Gem) && Gem.respond_to?(:loaded_specs)
          data[:versions] = {}

          Gem.loaded_specs.each do |k, v|
            data[:versions][k] = v.version.to_s
          end
        end

        data
      rescue => e
        ::Instana.logger.error "#{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}"
        ::Instana.logger.debug e.backtrace.join("\r\n")
        return data
      end

      # Used in class initialization and after a fork, this method
      # collects up process information
      #
      def collect_process_info
        process = {}
        cmdline = ProcTable.ps(Process.pid).cmdline.split("\0")
        process[:name] = cmdline.shift
        process[:arguments] = cmdline

        if RUBY_PLATFORM =~ /darwin/i
          # Handle OSX bug where env vars show up at the end of process name
          # such as MANPATH etc..
          process[:name].gsub!(/[_A-Z]+=\S+/, '')
          process[:name].rstrip!
        end

        process[:pid] = Process.pid
        # This is usually Process.pid but in the case of docker, the host agent
        # will return to us the true host pid in which we use to report data.
        process[:report_pid] = nil
        process
      end
    end
  end
end
