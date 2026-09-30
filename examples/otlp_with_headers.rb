# frozen_string_literal: true

# (c) Copyright IBM Corp. 2025

# OTLP Authenticated Export Example — Headers and TLS/mTLS
# =========================================================
#
# Demonstrates configuring authentication headers and TLS certificates
# for OTLP export. Use this when your OTLP endpoint requires an API key,
# tenant header, or mutual TLS client certificates.
#
# Prerequisites:
#   - Instana agent (or OTel Collector) running with TLS/auth enabled
#   - instana gem pointing to this repo (or installed)
#
# ---
# Run with headers only (no TLS):
#
#   INSTANA_TRACING_OTLP_ENABLED=true \
#   OTEL_EXPORTER_OTLP_HEADERS="x-instana-key=YOUR_API_KEY,x-tenant-id=YOUR_TENANT" \
#   ruby examples/otlp_with_headers.rb
#
# ---
# Run with TLS (server certificate verification):
#
#   INSTANA_TRACING_OTLP_ENABLED=true \
#   OTEL_EXPORTER_OTLP_ENDPOINT=https://your-collector:4318/v1/traces \
#   OTEL_EXPORTER_OTLP_CERTIFICATE=/path/to/ca-cert.pem \
#   ruby examples/otlp_with_headers.rb
#
# ---
# Run with mutual TLS (mTLS — client cert + key):
#
#   INSTANA_TRACING_OTLP_ENABLED=true \
#   OTEL_EXPORTER_OTLP_ENDPOINT=https://your-collector:4318/v1/traces \
#   OTEL_EXPORTER_OTLP_CERTIFICATE=/path/to/ca-cert.pem \
#   OTEL_EXPORTER_OTLP_CLIENT_KEY=/path/to/client-key.pem \
#   OTEL_EXPORTER_OTLP_CLIENT_CERTIFICATE=/path/to/client-cert.pem \
#   ruby examples/otlp_with_headers.rb
#
# ---
# Equivalent YAML config (INSTANA_CONFIG_PATH=/path/to/config.yml):
#
#   tracing:
#     otlp:
#       enabled: true
#       endpoint: "https://your-collector:4318/v1/traces"
#       headers:
#         x-instana-key: "YOUR_API_KEY"
#         x-tenant-id:   "YOUR_TENANT"
#       certificate:        "/path/to/ca-cert.pem"
#       client_key:         "/path/to/client-key.pem"
#       client_certificate: "/path/to/client-cert.pem"
#
# ---
# Header format for OTEL_EXPORTER_OTLP_HEADERS:
#   Comma-separated key=value pairs (no spaces around = or ,)
#   e.g. "api-key=secret123,x-tenant-id=myorg,x-custom=value"

require 'instana'

# ---------------------------------------------------------------------------
# Wait for the Instana agent to be ready before creating spans.
# See otlp_http.rb for a full explanation of why this is needed in scripts.
# ---------------------------------------------------------------------------
deadline = Time.now + 15
sleep(0.1) until Instana.agent.ready? || Time.now > deadline
abort('[otlp_with_headers] Agent not ready after 15 s — is the Instana agent running?') unless Instana.agent.ready?

puts "[otlp_with_headers] Agent ready — sending 5 spans via OTLP"

# ---------------------------------------------------------------------------
# Emit a representative set of spans to exercise the export path.
# The headers and certificates are set via env vars above; the span
# content here is identical to otlp_http.rb for easy comparison.
# ---------------------------------------------------------------------------

# 1. Basic span
Instana.tracer.in_span('otlp.auth.basic') do
  sleep(0.01)
end

# 2. HTTP exit span
Instana.tracer.in_span(
  'GET',
  attributes: {
    'http.method' => 'GET',
    'http.url' => 'https://api.example.com/profile',
    'http.status_code' => 200
  },
  kind: Instana::Trace::SpanKind::CLIENT
) do
  sleep(0.01)
end

# 3. Database span
Instana.tracer.in_span(
  'activerecord',
  attributes: {
    'activerecord.sql' => 'SELECT "profiles".* FROM "profiles" WHERE "profiles"."id" = ?',
    'activerecord.adapter' => 'PostgreSQL'
  }
) do
  sleep(0.01)
end

# 4. Nested spans
Instana.tracer.in_span('otlp.auth.parent') do
  Instana.tracer.in_span('otlp.auth.child') do
    sleep(0.01)
  end
end

# 5. Error span
begin
  Instana.tracer.in_span('otlp.auth.error') do
    raise StandardError, 'Auth example error'
  end
rescue StandardError
  # captured inside span
end

sleep(2)

puts 'otlp_with_headers.rb complete — check agent/Instana UI for 5 spans'
