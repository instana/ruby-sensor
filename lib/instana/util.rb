module Instana
  module Util
    class << self
      ID_RANGE = -2**63..2**63-1

      # An agnostic approach to method aliasing.
      #
      # @param klass [Object] The class or module that holds the method to be alias'd.
      # @param method [Symbol] The name of the method to be aliased.
      #
      def method_alias(klass, method)
        if klass.method_defined?(method.to_sym) ||
            klass.private_method_defined?(method.to_sym)

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

      # Calls on target_class to 'extend' cls
      #
      # @param target_cls [Object] the class/module to do the 'extending'
      # @param cls [Object] the class/module to be 'extended'
      #
      def send_extend(target_cls, cls)
        target_cls.send(:extend, cls) if defined?(target_cls)
      end

      # Calls on <target_cls> to include <cls> into itself.
      #
      # @param target_cls [Object] the class/module to do the 'including'
      # @param cls [Object] the class/module to be 'included'
      #
      def send_include(target_cls, cls)
        target_cls.send(:include, cls) if defined?(target_cls)
      end

      # Debugging helper method
      #
      def pry!
        # Only valid for development or test environments
        #env = ENV['RACK_ENV'] || ENV['RAILS_ENV']
        #return unless %w(development, test).include? env
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
      rescue LoadError
        ::Instana.logger.warn("No debugger in bundle.  Couldn't load pry-byebug.")
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
        data[:rpl] = RUBY_PATCHLEVEL if defined?(RUBY_PATCHLEVEL)

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
        ::Instana.logger.debug { "#{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}" }
        ::Instana.logger.debug { e.backtrace.join("\r\n") }
        return data
      end

      # Used in class initialization and after a fork, this method
      # collects up process information
      #
      def collect_process_info
        process = {}
        cmdline_file = "/proc/#{Process.pid}/cmdline"

        # If there is a /proc filesystem, we read this manually so
        # we can split on embedded null bytes.  Otherwise (e.g. OSX, Windows)
        # use ProcTable.
        if File.exist?(cmdline_file)
          cmdline = IO.read(cmdline_file).split(?\x00)
        else
          # Attempt to support older versions of sys-proctable and ffi.
          #
          # Alternatively we could use Sys::ProcTable::VERSION here but the
          # consistency across historical versions is unknown.  Alternative
          # to the alternative, would be Ruby metaprogramming using the `arity`
          # and `parameters` methods.
          # e.g ProcTable.method(:ps).arity/parameters
          if Gem.loaded_specs.key?("sys-proctable") &&
            (Gem.loaded_specs["sys-proctable"].version >= Gem::Version.new("1.2.0"))
            cmdline = ProcTable.ps(:pid => Process.pid).cmdline.split(' ')
          else
            cmdline = ProcTable.ps(Process.pid).cmdline.split(' ')
          end
        end

        if RUBY_PLATFORM =~ /darwin/i
          cmdline.delete_if{ |e| e.include?('=') }
          process[:name] = cmdline.join(' ')
        else
          process[:name] = cmdline.shift
          process[:arguments] = cmdline
        end

        process[:pid] = Process.pid
        # This is usually Process.pid but in the case of containers, the host agent
        # will return to us the true host pid in which we use to report data.
        process[:report_pid] = nil
        process
      end

      # Best effort to determine a name for the instrumented application
      # on the dashboard.
      #
      def get_app_name
        if ENV.key?('INSTANA_SERVICE_NAME')
          return ENV['INSTANA_SERVICE_NAME']
        end

        if defined?(::Resque)
          # Just because Resque is defined doesn't mean this is a resque process necessarily
          # Check arguments for a match
          if ($0 =~ /resque-#{Resque::Version}/)
            return "Resque Worker"
          elsif ($0 =~ /resque-pool-master/)
            return "Resque Pool Master"
          elsif ($0 =~ /resque-scheduler/)
            return "Resque Scheduler"
          end
        end

        if defined?(::RailsLts) || defined?(::Rails)
          return Rails.application.class.to_s.split('::')[0]
        end

        if $0.to_s.empty?
          return "Ruby"
        end

        exe = File.basename($0)
        if exe == "rake"
          return "Rake"
        end

        return exe
      rescue Exception => e
        Instana.logger.info "#{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}"
        Instana.logger.debug { e.backtrace.join("\r\n") }
        return "Ruby"
      end

      # Get the current time in milliseconds from the epoch
      #
      # @return [Integer] the current time in milliseconds
      #
      def now_in_ms
        Process.clock_gettime(Process::CLOCK_REALTIME, :millisecond)
      end
      # Prior method name support.  To be deprecated when appropriate.
      alias ts_now now_in_ms

      # Convert a Time value to milliseconds
      #
      # @param time [Time]
      #
      def time_to_ms(time)
        (time.to_f * 1000).floor
      end

      # Generate a random 64bit/128bit ID
      #
      # @param size [Integer] Number of 64 bit integers used to generate the id
      #
      # @return [String] a random 64bit/128bit hex encoded string
      #
      def generate_id(size = 1)
        Array.new(size) { rand(ID_RANGE) }
          .pack('q>*')
          .unpack('H*')
          .first
      end

      # Convert an ID to a value appropriate to pass in a header.
      #
      # @param id [String] the id to be converted
      #
      # @return [String]
      #
      def id_to_header(id)
        return '' unless id.is_a?(String)
        # Only send 64bit IDs downstream for now 
        id.length == 32 ? id[16..-1] : id
      end

      # Convert a received header value into a valid ID
      #
      # @param header_id [String] the header value to be converted
      #
      # @return [String]
      #
      def header_to_id(header_id)
        header_id.is_a?(String) && header_id.match(/\A[a-z\d]{16,32}\z/i) ? header_id : ''
      end
    end
  end
end
