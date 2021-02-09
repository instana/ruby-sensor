# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2016

require "instana/setup"

# Boot the instana agent background thread.  If you wish to have greater
# control on the where and which thread this is run in, instead use
#
#   gem "instana", :require => "instana/setup"
#
# ...and override ::Instana::Agent.spawn_background_thread to boot
# the thread of your choice.
#

::Instana.agent.spawn_background_thread
