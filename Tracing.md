# Tracing

Tracing with Instana is automatic but if you want even more visibility into custom code or some in-house
component, you can use the following API to report additional trace data to Instana.

# The API

The Instana Ruby gem provides a simple to use API to trace any arbitrary part of your application.

To instrument a section of code, it can be simply done with:

```Ruby
begin
  ::Instana.tracer.log_entry(:mywork, { :helpful_kvs => @user.id })
  # The code to be instrumented
  @id = User.find_by_name('john.smith')
rescue => e
  ::Instana.tracer.log_error(e)
ensure
  ::Instana.tracer.log_exit(:mywork, { :found_id => @id })
end
```

The above is a simple example but shows how easy it is to instrument any code you like.  Instana will
take care of the rest.

See the [examples directory](https://github.com/instana/ruby-sensor/blob/master/examples/tracing.rb) for
an expanded view and quick cheat sheet on tracing.

# Asynchronous Tracing

Some operations that you want to trace might be asynchronous meaning that they may return immediately
but will still continue to work out of band.  To do this, you can use  the `log_async_*` related 
tracing methods:

```Ruby
::Instana.tracer.log_entry(:prep_job, { :helpful_kvs => @job.name })

# The Async proc that will be executed out of band.
block = Proc.new do 
  t_context = ::Instana.tracer.log_async_entry(:my_async_op, { :helpful_kvs => true })
  # Some Asynchronous work to be done
  ::Instana.tracer.log_async_info({:info_kv => 1}, t_context)
  # More Asynchronous work
  ::Instana.tracer.log_async_exit(:my_async_op, { :helpful_exit_kv => true }, t_context)
end

MyClass.run_in_1_minute(block)

::Instana.tracer.log_exit(:prep_job, { :helpful_kvs => @job.name })

# Then later (even after this request/job has completed) you the block can be called and will be
# automatically be associated with the trace that spawned it.
block.call
```

# Carrying Context into New Threads

Tracing is thread local.  If you spawn a new thread the context must be carried to that new thread and then picked up.

```Ruby
# Get the tracing context
t_context = ::Instana.tracer.context

# Spawn new thread
Thread.new do
  # Pickup context in this thread with `t_context`
  ::Instana.tracer.log_start_or_continue(:async_thread, { :async_start => 1 }, t_context)
  
  # Continue tracing work as usual
  begin
    ::Instana.tracer.log_entry(:mywork, { :helpful_kvs => @user.id })
    # The code to be instrumented
    @id = User.find_by_name('john.smith')
  rescue => e
    ::Instana.tracer.log_error(e)
  ensure
    ::Instana.tracer.log_exit(:mywork, { :found_id => @id })
  end
end
```

