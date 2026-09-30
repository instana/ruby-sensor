# Instana Ruby Sensor — Examples

This directory contains runnable example scripts for the `instana` gem.

## Files

| File | What it demonstrates |
|---|---|
| [`otel.rb`](otel.rb) | Tracing API: `in_span`, `start_span`, nested spans, error recording, tags |
| [`tracing.rb`](tracing.rb) | Legacy tracing API examples |
| [`otlp_http.rb`](otlp_http.rb) | OTLP export via HTTP/protobuf — minimal quickstart |
| [`otlp_with_headers.rb`](otlp_with_headers.rb) | OTLP export with authentication headers and TLS/mTLS |

---

## Prerequisites

- Ruby 3.2 or newer (tested on Ruby 4.0.0)
- `instana` gem installed (or Gemfile pointing to a local checkout)
- **Instana agent running locally** with OTLP enabled on port `4318`

Verify the agent is reachable before running OTLP examples:

```bash
curl -s http://localhost:42699/
# Should return a JSON response

curl -s -o /dev/null -w "%{http_code}" \
  -X POST http://localhost:4318/v1/traces \
  -H "Content-Type: application/x-protobuf"
# Expect 200 or 415 — not "connection refused"
```

---

## Running the examples

### Tracing API (`otel.rb`)

```bash
bundle exec ruby examples/otel.rb
```

No environment variables needed — uses the native agent reporting path.

---

### OTLP HTTP/protobuf quickstart (`otlp_http.rb`)

Sends 5 spans (basic, HTTP exit, database, nested, error) to the Instana
agent via OTLP HTTP/protobuf. The endpoint is auto-derived from the agent
host — no explicit endpoint configuration required.

```bash
INSTANA_TRACING_OTLP_ENABLED=true \
bundle exec ruby examples/otlp_http.rb
```

**Optional — explicit endpoint:**
```bash
INSTANA_TRACING_OTLP_ENABLED=true \
OTEL_EXPORTER_OTLP_TRACES_ENDPOINT=http://localhost:4318/v1/traces \
bundle exec ruby examples/otlp_http.rb
```

> **Note on `OTEL_EXPORTER_OTLP_ENDPOINT` vs `OTEL_EXPORTER_OTLP_TRACES_ENDPOINT`:**
> - `OTEL_EXPORTER_OTLP_ENDPOINT` — base URL only (e.g. `http://localhost:4318`).
>   The sensor appends `/v1/traces` automatically per the OTLP spec.
> - `OTEL_EXPORTER_OTLP_TRACES_ENDPOINT` — fully-qualified URL including path.
>   Used as-is; takes precedence over `OTEL_EXPORTER_OTLP_ENDPOINT`.

**Expected log output:**
```
Using OTLP Exporter to export result code: 0
```

**Result code meanings:**
- `0` — `SUCCESS` — spans delivered
- `1` — `FAILURE` — connection error or endpoint unreachable
- `2` — `DROPPED` — batch rejected by the receiver

---

### OTLP with headers and TLS (`otlp_with_headers.rb`)

#### Headers only (no TLS)

```bash
INSTANA_TRACING_OTLP_ENABLED=true \
OTEL_EXPORTER_OTLP_HEADERS="x-instana-key=YOUR_API_KEY,x-tenant-id=YOUR_TENANT" \
bundle exec ruby examples/otlp_with_headers.rb
```

Header format: comma-separated `key=value` pairs, no spaces around `=` or `,`.

#### TLS — server certificate verification

```bash
INSTANA_TRACING_OTLP_ENABLED=true \
OTEL_EXPORTER_OTLP_ENDPOINT=https://your-collector:4318/v1/traces \
OTEL_EXPORTER_OTLP_CERTIFICATE=/path/to/ca-cert.pem \
bundle exec ruby examples/otlp_with_headers.rb
```

#### Mutual TLS (mTLS)

```bash
INSTANA_TRACING_OTLP_ENABLED=true \
OTEL_EXPORTER_OTLP_ENDPOINT=https://your-collector:4318/v1/traces \
OTEL_EXPORTER_OTLP_CERTIFICATE=/path/to/ca-cert.pem \
OTEL_EXPORTER_OTLP_CLIENT_KEY=/path/to/client-key.pem \
OTEL_EXPORTER_OTLP_CLIENT_CERTIFICATE=/path/to/client-cert.pem \
bundle exec ruby examples/otlp_with_headers.rb
```

#### Equivalent YAML config

```bash
cat > /tmp/instana_otlp.yml << 'EOF'
tracing:
  otlp:
    enabled: true
    endpoint: "https://your-collector:4318/v1/traces"
    headers:
      x-instana-key: "YOUR_API_KEY"
      x-tenant-id:   "YOUR_TENANT"
    certificate:        "/path/to/ca-cert.pem"
    client_key:         "/path/to/client-key.pem"
    client_certificate: "/path/to/client-cert.pem"
EOF

INSTANA_CONFIG_PATH=/tmp/instana_otlp.yml \
bundle exec ruby examples/otlp_with_headers.rb
```

> **Note:** gRPC (`OTEL_EXPORTER_OTLP_PROTOCOL=grpc`) is not supported.
> Only `http/protobuf` is supported.
