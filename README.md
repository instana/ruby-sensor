# Instana

The `instana` gem provides Ruby metrics and traces (request, queue & cross-host) for [Instana](https://www.instana.com/).

## Ruby Version Support

This gem requires Ruby 3.2 or greater. We actively test and maintain compatibility with Ruby versions 3.2, 3.3, 3.4, and 4.0 to ensure optimal performance and reliability. As part of our commitment to supporting the Ruby community, we continue to provide support for Ruby versions up to 1 year after their official End-of-Life (EOL) date, giving you ample time to plan and execute version upgrades.

Any and all feedback is welcome.  Happy Ruby visibility.

[![Gem Version](https://badge.fury.io/rb/instana.svg)](https://badge.fury.io/rb/instana)
[![CircleCI](https://circleci.com/gh/instana/ruby-sensor.svg?style=svg)](https://circleci.com/gh/instana/ruby-sensor)
[![OpenTracing Badge](https://img.shields.io/badge/OpenTracing-disabled-red.svg)](http://opentracing.io)
[![OpenTelemetry Badge](https://img.shields.io/badge/OpenTelemetry-enabled-blue.svg)](http://opentelemetry.io)

## Installation

The gem is available on [Rubygems](https://rubygems.org/gems/instana).  To install, add this line to _the end_ of your application's Gemfile:

```ruby
gem 'instana'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install instana

## Usage

The `instana` gem is a zero configuration tool that will automatically collect key metrics and distributed traces from your Ruby processes.  Just install and go.

### Supported Frameworks

* [Cuba](https://cuba.is/)
* [gRPC](https://grpc.io/)
* [Padrino](https://padrinorb.com/)
* [Roda](https://roda.jeremyevans.net/)
* [Ruby on Rails](https://rubyonrails.org/)
* [Rack](https://rack.github.io/)
* [Sinatra](https://sinatrarb.com/)

## Configuration

Although the gem has no configuration required for out of the box metrics and tracing, components can be configured if needed.  See our [Configuration](https://www.ibm.com/docs/en/instana-observability/current?topic=ruby-configuration-configuring-instana-gem) page.

## Tracing

This Ruby gem provides a simple API for tracing and also supports [OpenTracing](http://opentracing.io/).  See the [Ruby Tracing SDK](https://www.ibm.com/docs/en/instana-observability/current?topic=ruby-tracing-sdk) and [OpenTracing](https://www.ibm.com/docs/en/instana-observability/current?topic=ruby-opentracing) pages for details.

## OTLP Export

The `instana` gem supports exporting traces via the **OpenTelemetry Protocol (OTLP)**
directly to the Instana agent's OTLP receiver, bypassing the native agent trace format.
OTLP export is **opt-in** — the gem behaves identically to previous versions when
`INSTANA_TRACING_OTLP_ENABLED` is not set.

### Overview

When OTLP export is enabled:
- Spans are converted from Instana's internal format to OTLP protobuf
- The converted spans are sent via HTTP/protobuf to the agent's OTLP port (`4318`)
- The endpoint is auto-derived from the same host where the Instana agent was discovered
- The native agent reporting path (`/com.instana.plugin.ruby/traces`) is replaced by OTLP

### Quick Start

The only required change is setting one environment variable before starting your application:

```bash
INSTANA_TRACING_OTLP_ENABLED=true bundle exec rails server
```

Expected log output (with `INSTANA_LOG_LEVEL=debug`):
```
[Instana] Using OTLP Exporter to export result code: 0
```

Result code `0` = `SUCCESS`. No other configuration is needed — the endpoint is
automatically set to `http://<agent-host>:4318/v1/traces`.

### Gem Dependencies

`opentelemetry-exporter-otlp` is a **runtime dependency** of the `instana` gem and
is installed automatically. No additional gems are required.

> **Note:** gRPC (`OTEL_EXPORTER_OTLP_PROTOCOL=grpc`) is not supported.
> Only `http/protobuf` is supported and tested.

### Environment Variables

| Variable | Type | Default | Description |
|---|---|---|---|
| `INSTANA_TRACING_OTLP_ENABLED` | Boolean | `false` | Enables OTLP export. Valid values: `true`, `1`, `yes` |
| `OTEL_EXPORTER_OTLP_ENDPOINT` | String (URL) | auto-derived from agent host | **Base** endpoint URL. `/v1/traces` is appended automatically. |
| `OTEL_EXPORTER_OTLP_TRACES_ENDPOINT` | String (URL) | `<OTEL_EXPORTER_OTLP_ENDPOINT>/v1/traces` | **Fully-qualified** trace endpoint. Used as-is; overrides `OTEL_EXPORTER_OTLP_ENDPOINT`. |
| `OTEL_EXPORTER_OTLP_PROTOCOL` | String | `http/protobuf` | Transport protocol. Only `http/protobuf` is supported. |
| `OTEL_EXPORTER_OTLP_HEADERS` | String | — | Comma-separated `key=value` auth headers. e.g. `api-key=secret,x-tenant-id=myorg` |
| `OTEL_EXPORTER_OTLP_TIMEOUT` | Integer (ms) | `10000` | Maximum time to wait for export completion. |
| `OTEL_EXPORTER_OTLP_COMPRESSION` | String | — | Compression algorithm. Valid value: `gzip`. |
| `OTEL_EXPORTER_OTLP_CERTIFICATE` | String (path) | — | Path to CA certificate file for TLS verification. |
| `OTEL_EXPORTER_OTLP_CLIENT_KEY` | String (path) | — | Path to client private key file for mutual TLS. |
| `OTEL_EXPORTER_OTLP_CLIENT_CERTIFICATE` | String (path) | — | Path to client certificate file for mutual TLS. |
| `OTEL_EXPORTER_OTLP_INSECURE` | Boolean | `false` | Disable TLS certificate verification. |
| `OTEL_SEMCONV_STABILITY_OPT_IN` | String | `stable` | Semantic convention stability level. Valid values: `stable`, `development`. |

> **Endpoint precedence:** `OTEL_EXPORTER_OTLP_TRACES_ENDPOINT` > `OTEL_EXPORTER_OTLP_ENDPOINT` > auto-derived from agent host

### YAML Configuration

When `INSTANA_CONFIG_PATH` points to a YAML file, OTLP settings are placed under
the `tracing.otlp` key. YAML configuration takes precedence over environment variables.

**Minimal example** (`config/instana.yml`):
```yaml
tracing:
  otlp:
    enabled: true
```

**Full example:**
```yaml
tracing:
  otlp:
    enabled: true
    endpoint: "http://localhost:4318/v1/traces"
    protocol: "http/protobuf"
    timeout: 10000
    compression: "gzip"
    headers:
      x-instana-key: "YOUR_API_KEY"
      x-tenant-id:   "YOUR_TENANT"
    certificate:        "/path/to/ca-cert.pem"
    client_key:         "/path/to/client-key.pem"
    client_certificate: "/path/to/client-cert.pem"
    insecure: false
    semconv_stability: "stable"
```

Start the application:
```bash
INSTANA_CONFIG_PATH=config/instana.yml bundle exec rails server
```

### Configuration Precedence

Settings are resolved in this order (highest wins):

```
INSTANA_CONFIG_PATH YAML  →  Environment variables  →  Agent config  →  Defaults
```

This means a YAML file always wins over env vars. Agent-provided config (pushed
via the Instana agent's discovery payload) is applied after env vars but can be
overridden by YAML or env vars set at startup.

### TLS / mTLS

**Server-side TLS** (verify the collector's certificate):
```bash
INSTANA_TRACING_OTLP_ENABLED=true \
OTEL_EXPORTER_OTLP_ENDPOINT=https://your-collector:4318/v1/traces \
OTEL_EXPORTER_OTLP_CERTIFICATE=/path/to/ca-cert.pem \
bundle exec rails server
```

**Mutual TLS** (client certificate authentication):
```bash
INSTANA_TRACING_OTLP_ENABLED=true \
OTEL_EXPORTER_OTLP_ENDPOINT=https://your-collector:4318/v1/traces \
OTEL_EXPORTER_OTLP_CERTIFICATE=/path/to/ca-cert.pem \
OTEL_EXPORTER_OTLP_CLIENT_KEY=/path/to/client-key.pem \
OTEL_EXPORTER_OTLP_CLIENT_CERTIFICATE=/path/to/client-cert.pem \
bundle exec rails server
```

### Troubleshooting

**OTLP export is not happening — spans go via the native path**

OTLP is disabled by default. Check that `INSTANA_TRACING_OTLP_ENABLED=true` is set
in the process environment before the gem initialises (i.e. before `require 'instana'`
or Rails boot). Verify with:
```bash
INSTANA_LOG_LEVEL=debug bundle exec rails server
# Look for: "Using OTLP Exporter" vs "Using Instana Native Exporter"
```

**`Failed to initialize OTLP exporter` in the log**

The exporter could not be constructed. Common causes:
- `OTEL_EXPORTER_OTLP_CERTIFICATE` path does not exist or is not readable
- `OTEL_EXPORTER_OTLP_CLIENT_KEY` / `OTEL_EXPORTER_OTLP_CLIENT_CERTIFICATE` path invalid
- An unsupported protocol (e.g. `grpc`) was set — only `http/protobuf` is supported

The gem falls back to `@otlp_exporter = nil` and logs an `ERROR` line with the
exception message. Check that message for the root cause.

**`result code: 1` (FAILURE) — spans not arriving**

The exporter initialised but the export request failed. Common causes:
- The Instana agent is not running or OTLP is not enabled on the agent side
- `OTEL_EXPORTER_OTLP_ENDPOINT` points to a wrong host or port
- `OTEL_EXPORTER_OTLP_ENDPOINT` was set to a base URL like `http://host:4318`
  without `/v1/traces` — this was a known bug fixed in v2.9.0 (the sensor now
  appends the path automatically)
- A firewall is blocking port `4318`

Verify the agent OTLP port is reachable:
```bash
curl -s -o /dev/null -w "%{http_code}" \
  -X POST http://localhost:4318/v1/traces \
  -H "Content-Type: application/x-protobuf"
# 200 or 415 = port open; "connection refused" = agent OTLP not enabled
```

**`HTTP request path is empty` exception (pre-v2.9.0)**

If you are on a version earlier than 2.9.0 and pass a base URL to
`OTEL_EXPORTER_OTLP_ENDPOINT` (without `/v1/traces`), the `opentelemetry-exporter-otlp`
gem crashes with `HTTP request path is empty`. Upgrade to v2.9.0 or later, or use
`OTEL_EXPORTER_OTLP_TRACES_ENDPOINT` with the full path instead.

## Documentation

You can find more documentation covering supported components and minimum versions in the Instana [documentation portal](https://www.ibm.com/docs/en/instana-observability/current?topic=technologies-monitoring-ruby).

## Want End User Monitoring (EUM)?

Instana provides deep end user monitoring that links server side traces with browser events to give you a complete view from server to browser.

See the [End User Monitoring](https://www.ibm.com/docs/en/instana-observability/current?topic=instana-monitoring-websites) page for more information.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bundle exec rake console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `lib/instana/version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/instana/ruby-sensor.

## More

Want to instrument other languages?  See our [Node.js](https://github.com/instana/nodejs), [Go](https://github.com/instana/golang-sensor), [Python](https://github.com/instana/python-sensor) repositories or [many other supported technologies](https://www.instana.com/supported-technologies/).
