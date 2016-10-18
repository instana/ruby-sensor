module Instana
  ##
  # Debugging helper method
  #
  def self.pry!
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
