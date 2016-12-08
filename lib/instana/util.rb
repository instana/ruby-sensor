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
    end
  end
end
