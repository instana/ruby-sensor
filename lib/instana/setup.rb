# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2016

require 'oj_check'

require "instana/base"
require "instana/config"
require "instana/agent"
require "instana/collector"
require "instana/secrets"
require "instana/tracer"
require "instana/tracing/processor"

require 'instana/activator'

::Instana.setup
::Instana.agent.setup
::Instana::Activator.start

# Register the metric collectors
unless RUBY_PLATFORM == 'java'.freeze
  require 'instana/collectors/gc'
end

require 'instana/collectors/memory'
require 'instana/collectors/thread'

# Require supported OpenTracing interfaces
require "opentracing"

# The Instana agent is now setup.  The only remaining
# task for a complete boot is to call
# `Instana.agent.start` in the thread of your choice.
# This can be in a simple `Thread.new` block or
# any other thread system you may use (e.g. actor
# threads).
#
# Note that `start` should only be called once per process.
#
# Thread.new do
#   ::Instana.agent.start
# end
