# Tracing

Tracing with Instana is automatic but if you want even more visibility into custom code or some in-house
component, you can use Instana's tracing API or [OpenTracing](http://opentracing.io/).

# OpenTracing

Existing applications that utilize the OpenTracing API or those who wish to add support should have no problem
as the Instana Ruby gem fully supports the OpenTracing specification.

To start, simply set the Instana tracer as the global tracer for OpenTracing:

```Ruby
require 'opentracing'
OpenTracing.global_tracer = ::Instana.tracer
```

Then OpenTracing code can be run normally:

```Ruby
begin
  span = OpenTracing.start_span('job')
  # The code to be instrumented
  @id = User.find_by_name('john.smith')
  span.set_tag(:job_id, @id)
rescue => e
  span.set_tag(:error, e.message)
ensure
  span.finish
end
```

# The Instana Ruby API

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

or alternatively you can use the `trace` block method that will automagically capture and
log any exceptions raised:

```Ruby
::Instana.tracer.trace(:mywork, { :helpful_kvs => @user.id }) do
  # The code to be instrumented
  @id = User.find_by_name('john.smith')
 end
```

The above are simple examples but shows how easy it is to instrument any arbitrary piece of code you like.

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
