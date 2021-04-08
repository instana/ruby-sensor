# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2016

require 'instana/logger_delegator'

require "instana/base"
require "instana/config"
require "instana/secrets"
require "instana/tracer"
require "instana/tracing/processor"

require 'instana/serverless'

require 'instana/activator'

require 'instana/backend/request_client'
require 'instana/backend/gc_snapshot'
require 'instana/backend/process_info'

require 'instana/snapshot/deltable'
require 'instana/snapshot/ruby_process'
require 'instana/snapshot/fargate_process'
require 'instana/snapshot/fargate_task'
require 'instana/snapshot/fargate_container'
require 'instana/snapshot/docker_container'
require 'instana/snapshot/lambda_function'

require 'instana/backend/host_agent_lookup'
require 'instana/backend/host_agent_activation_observer'
require 'instana/backend/host_agent_reporting_observer'

require 'instana/backend/host_agent'
require 'instana/backend/serverless_agent'
require 'instana/backend/agent'

::Instana.setup
::Instana.agent.setup
::Instana::Activator.start

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
