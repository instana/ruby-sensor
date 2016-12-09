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

http_ops = {:get => "/", :post => "/post_data"}

cb_block = Proc.new do |response, payload|
  # The callback block that is invoked on HTTP response (payload == t_context)
  #
  # process response
  #
  ::Instana.tracer.log_async_exit(:http_op, :status => response.status, payload)
end

http_ops.each do |op|
  t_context = ::Instana.tracer.log_async_entry(:http_op)
  
  # Example op that returns immediately
  request_id = connection.async_request(op, cb_block, t_context)
  
  ::Instana.tracer.log_async_info({:request_id => request_id}, t_context)
end  
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
# Tracing Jobs Scheduled for Later

Jobs that are queued to be run later can be instrumented as such:

```Ruby
::Instana.tracer.log_entry(:prep_job, { :job_name => @job.name })

# Get the current tracing context
t_context = ::Instana.tracer.context

# The Async proc (job) that will be executed out of band.
block = Proc.new do 
  # This will pickup context and link the two traces (root + job)
  t_context = ::Instana.tracer.log_start_or_continue_trace(:my_async_op, { :helpful_kvs => true }, t_context)
  #
  # Some Asynchronous work to be done
  #
  ::Instana.tracer.log_info({:job_name => Job.get(id).name})
  # More Asynchronous work
  ::Instana.tracer.log_end(:my_async_op, { :job_success => true })
end

MyClass.run_in_5_minutes(block)

::Instana.tracer.log_exit(:prep_job, { :prep_successful => true })
```
