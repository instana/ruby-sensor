# This file outlines the Instana Ruby Tracing API.
#
# This same tracer also supports OpenTracing.  See `opentracing.rb` for
# separate documentation.

# This API is also documented on rubydoc:
# http://www.rubydoc.info/gems/instana/1.7.8/Instana/Tracer

#######################################
## Block tracing
#######################################

#Instana::Tracer.start_or_continue_trace(name, kvs, incoming_context) - Initiates tracing
#Instana::Tracer.trace(name, kvs) - starts a new span in an existing Trace

# <start_or_continue_trace> will initiate a new trace.  Often used at entry
# points in webservers (e.g. rack), it will initialize tracing and instrument the passed
# block.  <incoming_id> is a hash for continuing remote traces (remote in terms
# of service calls, or message queues).

# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2016

Instana::Tracer.start_or_continue_trace(:my_block_name, {}, incoming_context) do
  # Code block
end

# <trace> will instrument a block of code in an already running trace.
# This is the most common use case (instead of initiating new
# traces).
Instana::Tracer.trace(:postgres, {:user => 'postgres'}) do
  @postgres.select(1)
end

#######################################
## Lower level logging
#######################################

# <log_start_or_continue_trace> will initiate a new trace.  Often used at entry
# points in webservers, it will establish a new trace (for web request,
# background jobs etc.).
# <incoming_context> is a hash for continuing remote traces (remote in terms
# of service calls, or message queues).
Instana::Tracer.log_start_or_continue(:rack, {}, incoming_context)

# <log_entry> will start a new span from the current span within
# a trace.
Instana::Tracer.log_entry(name, kvs)

# <log_exit> will close out the current span
Instana::Tracer.log_exit(name, kvs)

# <log_info> will append information to the current span in the
# trace.  Examples could be redis options, contextual data, user
# login status etc...
Instana::Tracer.log_info({:some_key => 'some_value'})

# <log_error> will log an exception to the current span in the
# trace.
Instana::Tracer.log_error(Exception)

# <log_end> closes out the current span, finishes
# the trace and adds it to ::Instana.processor
# for reporting.
Instana::Tracer.log_end(:rack, {})

#######################################
# Lower level API Example
######################################

# Full Tracing Lifecycle example
#
Instana::Tracer.log_start_or_continue(:mywebserver, {:user_id => @user_id})

begin
  Instana::Tracer.log_entry(:redis_lookup, {:redisdb => @redisdb.url})
  @redisdb.get(@user_id.session_id)
rescue => e
  Instana::Tracer.log_error(e)
ensure
  Instana::Tracer.log_exit(:redis_lookup)
end

Instana::Tracer.log_end(:mywebserver)
