# This file exists to just make the Instana::Rack require calls a bit more
# user friendly.
#
# The real file is in the instrumentation subdirectory:
# lib/instana/instrumentation/rack.rb
#
# require 'instana/rack'
# config.middleware.use ::Instana::Rack
#
require 'instana/instrumentation/rack'
