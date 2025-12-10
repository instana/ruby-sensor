# Simple Instana Tracing Examples
# ===========================

# (c) Copyright IBM Corp. 2025

#######################################
## in_span Method Examples
#######################################

# 1. Basic tracing - simplest way to trace code
Instana.tracer.in_span('my_operation') do
  # Your code here
end

# 2. HTTP request tracing with basic attributes
Instana.tracer.in_span('http.request',
                       attributes: {
                         'http.method' => 'GET',
                         'http.url' => 'https://example.com'
                       },
                       kind: Instana::Trace::SpanKind::CLIENT) do
  # HTTP request code here
end

# 3. Error handling - errors are automatically captured
begin
  Instana.tracer.in_span('risky_operation') do
    raise StandardError, 'Something went wrong'
  end
rescue
  # Handle error
end

# 4. Nested spans - parent-child relationship
Instana.tracer.in_span('parent') do
  # Parent code
  Instana.tracer.in_span('child') do
    # Child code
  end
end

# 5. Adding tags during execution
Instana.tracer.in_span('process_order') do |span|
  span.set_tag('order.id', 12345)
  span.set_tag('status', 'completed')
end

#######################################
## start_span Method Examples
#######################################

# 1. Basic manual span control
span = Instana.tracer.start_span('manual_operation')
# Your code here
span.finish

# 2. Spans across methods
def start_work
  span = Instana.tracer.start_span('long_process')
  # Initial work
  finish_work(span)
end

def finish_work(span)
  # More work
  span.finish
end

# 3. Async operations across threads
parent_span = Instana.tracer.start_span('main_task')

Thread.new do
  child_span = Instana.tracer.start_span('async_task',
                                         with_parent: parent_span.context)
  # Async work
  child_span.finish
end

parent_span.finish

# 4. Manual error handling
span = Instana.tracer.start_span('custom_error_handling')
begin
  # Your code here
rescue => e
  span.record_exception(e)
ensure
  span.finish
end

# 5. Parent-child relationship (explicit)
parent = Instana.tracer.start_span('parent_task')
child = Instana.tracer.start_span('child_task', with_parent: parent.context)

child.finish
parent.finish

# Made with Bob
