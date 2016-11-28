require "instana/setup"

# Boot the instana agent background thread.  If you wish to have greater
# control on the where and which thread this is run in, instead use
#
#   gem "instana", :require "instana/setup"
#
# ...and manually call ::Instana.agent.start in the thread
# of your choice
#
Thread.new do
  ::Instana.agent.start
end
