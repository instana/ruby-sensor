# Configuration

## Global Enable/Disable

The entire gem can be disabled at runtime with:

```Ruby
::Instana.config[:enabled] = false # default: true
```

Other global enable/disable options are:

```Ruby
# Enable/Disable metrics collection and reporting
Instana.config[:metrics][:enabled] # default true

# Enable/Disable tracing
Instana.config[:tracing][:enabled] # default true
```

## Enabling/Disabling Individual Components

Individual components can be enabled and disabled with a local config.

To disable a single component in the gem, you can disable a single component with the following code:

```Ruby
::Instana.config[:metrics][:gc][:enabled] = false
```
Current metric components are `:gc`, `:memory` and `:thread`.

Instrumentation can be disabled as:

```Ruby
::Instana.config[:excon][:enabled] = false
::Instana.config[:rack][:enabled] = false
```

## Rack Middleware

This gem will detect and automagically insert the Instana Rack middleware into the middleware stack when a [supported framework](https://instana.atlassian.net/wiki/display/DOCS/Ruby) is present.  We are currently adding support for more frameworks.  If you are using a yet to be instrumented framework, you can insert the Instana Rack middleware with the following:

```Ruby
require "instana/rack"
config.middleware.use ::Instana::Rack
```

...or whatever specific middleware call is appropriate for your framework.


## Managing the Agent Background Thread

This agent spawns a lightweight background thread to periodically collect and report metrics and traces.  Be default, this uses a standard Ruby thread.  If you wish to have greater control and potentially boot the agent reporting manually in an alternative thread system (such as actor based threads), you can do so with the following:

```Ruby
gem "instana", :require => "instana/setup"
```

...then in the background thread of your choice simply call:

```Ruby
::Instana.agent.start
```

Note that this call is blocking.  It kicks off a loop of timers that periodically collects and reports metrics and trace data.  This should only be called from inside an already initialized background thread:

```Ruby
Thread.new do
  ::Instana.agent.start
end
```

### Caveat

In the case of forking webservers such as Unicorn or Puma in clustered mode, the agent detects the pid change and re-spawns the background thread.  If you are managing the background thread yourself with the steps above _and_ you are using a forking webserver (or anything else that may fork the original process), you should also do the following.

When a fork is detected, the agent handles the re-initialization and then calls `::Agent.instana.spawn_background_thread`.  This by default uses the standard `Thread.new`.  If you wish to control this, you should override this method by re-defining that method.  For example:

```ruby
# This method can be overridden with the following:
#
module Instana
  class Agent
    def spawn_background_thread
      # start/identify custom thread
      ::Instana.agent.start
    end
  end
end
```

## Logging

The Instana logger is a standard Ruby logger that logs debug, warn, info
(etc.) messages and can be set as follows:

```Ruby
require "logger"
::Instana.logger.level = ::Logger::WARN
```

The gem can be configured to use your application logger instead:

```
::Instana.logger = ::Rails.logger
``

### Debugging & More Verbosity

#### Environment Variable

Setting `INSTANA_GEM_DEV` to a non nil value will enable extra logging output generally useful
for development.

#### Extended Debug Logging

The gem allows the debug level to be configured that affects
what extra debug info it reports.  It allows for:

* `:agent` - shows all agent state related debug messages
* `:agent_comm` - outputs all request/response pairs to and from the
  host agent
* `:trace` - outputs debug messages related to tracing and trace management

Log messages can be generated for these channels using:

```Ruby
::Instana.logger.agent("agent specific log msg")
::Instana.logger.agent_comm("agent communication specific log msg")
```

To set the debug log level:

```Ruby
::Instana.logger.debug_level = [:agent, :agent_comm, :trace]
# or
::Instana.logger.debug_level = [:agent_comm]
# or
::Instana.logger.debug_level = :agent
```

or to reset it:

```Ruby
::Instana.logger.debug_level = nil
```

Example output:
```bash
[2] pry(main)> Instana.logger.debug_level = :agent_comm
=> :agent_comm

D, [2016-12-01T11:45:12.876527 #74127] DEBUG -- : Instana: POST Req -> -body-: http://127.0.0.1:42699/com.instana.plugin.ruby.74127 ->
-{"gc":{"heap_live":171890,"heap_free":522},"memory":{"rss_size":51212.0}}- Resp -> body:#<Net::HTTPOK:0x007faee2161078> -> -[]-

[3] pry(main)> Instana.logger.debug_level = nil
=> nil
```
