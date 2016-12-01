# Configuration

## Logging

The Instana logger is a standard Ruby logger that logs debug, warn, info
(etc.) messages and can be set as follows:

```Ruby
require "logger"
::Instana.logger.level = ::Logger::WARN
```

It also allows the debug level to be configured that affects
what extra debug info it reports.  It allows for:

* `:agent` - shows all agent state related debug messages
* `:agent_comm` - outputs all request/response pairs to and from the
  host agent

Log messages can be generated for these channels using:

```Ruby
::Instana.logger.agent("agent specific log msg")
::Instana.logger.agent_comm("agent communication specific log msg")
```

To set the debug log level:

```Ruby
::Instana.logger.debug_level = [:agent, :agent_comm]
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
