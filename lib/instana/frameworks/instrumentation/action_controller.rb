if defined?(::ActionController) && ::Instana.config[:action_controller][:enabled]
  require "instana/frameworks/instrumentation/action_controller#{ActionPack::VERSION::MAJOR}"

  if ActionPack::VERSION::MAJOR >= 5
    ::ActionController::Base.send(:prepend, ::Instana::Instrumentation::ActionController)
  else
    ::ActionController::Base.send(:include, ::Instana::Instrumentation::ActionController)
  end
end
