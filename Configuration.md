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

## Agent Communication

The sensor tries to communicate with the Instana agent via IP 127.0.0.1 and as a fallback via the host's default gateway. Should the agent not be available under either of these IPs, e.g. due to iptables or other networking tricks, you can use the agentHost option to use a custom IP.

```Ruby
# Leverage environment variable
::Instana.config[:agent_host] = ENV['INSTANA_AGENT_HOST']

# Custom agent port
::Instana.config[:agent_port] = 42699
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

## Enable/Disable Backtrace Collection

Because backtraces are somewhat expensive in Ruby, backtrace collection is disabled by default but can be enabled with the following code:

```Ruby
::Instana.config[:collect_backtraces] = true
```

This will in-turn enable CodeView in your dashboard to get code level insights.

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
```

### Debugging & More Verbosity

#### Environment Variable

Setting `INSTANA_GEM_DEV` to a non nil value will enable extra logging output generally useful
for development.
