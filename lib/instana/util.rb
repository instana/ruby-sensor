require 'sys/proctable'
include Sys

module Instana
  module Util
    class << self
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
        cmdline_file = "/proc/#{Process.pid}/cmdline"

        ptable = ProcTable.ps(Process.pid)

        if RUBY_PLATFORM =~ /darwin/i ||
          RUBY_PLATFORM =~ /linux/i
          # SysProctable supports OSX, Linux well
          process[:name] = ptable.pname
          process[:arguments] = ptable.arguments
        else
          # Some other platform - try using /proc first
          if File.exist?(cmdline_file)
            cmdline = IO.read(cmdline_file).split(?\x00)
            process[:name] = cmdline.shift
            process[:arguments] = cmdline
          else
            # Last ditch effort
            parts = ptable.cmdline.split(' ')
            process[:name] = parts.shift
            process[:arguments] = parts
          end
        end

        process[:pid] = Process.pid
        # This is usually Process.pid but in the case of containers, the host agent
        # will return to us the true host pid in which we use to report data.
        process[:report_pid] = nil
        process
      end

      # Get the current time in milliseconds
      #
      # @return [Integer] the current time in milliseconds
      #
      def ts_now
        (Time.now.to_f * 1000).floor
      end

      # Convert a Time value to milliseconds
      #
      # @param time [Time]
      #
      def time_to_ms(time = Time.now)
        (time.to_f * 1000).floor
      end

      # Generate a random 64bit ID
      #
      # @return [Integer] a random 64bit integer
      #
      def generate_id
        # Max value is 9223372036854775807 (signed long in Java)
        rand(-2**63..2**63-1)
      end

      # Convert an ID to a value appropriate to pass in a header.
      #
      # @param id [Integer] the id to be converted
      #
      # @return [String]
      #
      def id_to_header(id)
        unless id.is_a?(Integer) || id.is_a?(String)
          Instana.logger.debug "id_to_header received a #{id.class}: returning empty string"
          return String.new
        end
        [id.to_i].pack('q>').unpack('H*')[0].gsub(/^0+/, '')
      rescue => e
        Instana.logger.error "#{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}"
        Instana.logger.debug e.backtrace.join("\r\n")
      end

      # Convert a received header value into a valid ID
      #
      # @param header_id [String] the header value to be converted
      #
      # @return [Integer]
      #
      def header_to_id(header_id)
        if !header_id.is_a?(String)
          Instana.logger.debug "header_to_id received a #{header_id.class}: returning 0"
          return 0
        end
        if header_id.length < 16
          # The header is less than 16 chars.  Prepend
          # zeros so we can convert correctly
          missing = 16 - header_id.length
          header_id = ("0" * missing) + header_id
        end
        [header_id].pack("H*").unpack("q>")[0]
      rescue => e
        Instana.logger.error "#{__method__}:#{File.basename(__FILE__)}:#{__LINE__}: #{e.message}"
        Instana.logger.debug e.backtrace.join("\r\n")
      end
    end
  end
end
