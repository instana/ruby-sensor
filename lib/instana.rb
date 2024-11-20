# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2016
if ENV.fetch('INSTANA_DISABLE', false) && defined?(::Instana)
  Object.send(:remove_const, :Instana)
end

# Boot the instana agent background thread.  If you wish to have greater
# control on the where and which thread this is run in, instead use
#
#   gem "instana", :require => "instana/setup"
#
# ...and override ::Instana::Agent.spawn_background_thread to boot
# the thread of your choice.
#

# :nocov:
unless ENV.fetch('INSTANA_DISABLE', false)
  require 'instana/setup'
  ::Instana::Activator.start
  ::Instana.agent.spawn_background_thread

  ::Instana.logger.info "Stan is on the scene.  Starting Instana instrumentation version #{::Instana::VERSION}"
end
# :nocov:
