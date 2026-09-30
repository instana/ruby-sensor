# frozen_string_literal: true

# (c) Copyright IBM Corp. 2026

# OTLP HTTP/protobuf Export Example
# ==================================
#
# Demonstrates enabling Instana OTLP export using the HTTP/protobuf protocol.
# Spans are sent directly to the Instana agent's OTLP receiver on port 4318,
# bypassing the native agent trace format.
#
# Prerequisites:
#   - Instana agent running locally with OTLP enabled on port 4318
#   - instana gem pointing to this repo (or installed)
#
# Run:
#   INSTANA_TRACING_OTLP_ENABLED=true \
#   OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf \
#   ruby examples/otlp_http.rb
#
# Optional — explicit endpoint (agent auto-discovers if omitted):
#   OTEL_EXPORTER_OTLP_TRACES_ENDPOINT=http://localhost:4318/v1/traces
#
# Expected output:
#   [Instana] Using OTLP Exporter to export result code: 0

require 'instana'

# ---------------------------------------------------------------------------
# Wait for the Instana agent to be ready before creating spans.
#
# Spans created while the agent is not ready are silently dropped —
# `Instana.tracer.start_span` returns a non-recording span when
# `Instana.agent.ready?` is false (discovery has not yet completed).
#
# In long-running servers (Rails, Rack) this is never an issue because
# the agent background thread finishes well before the first request
# arrives. In short-lived scripts the agent must be ready first.
# ---------------------------------------------------------------------------
deadline = Time.now + 15
sleep(0.1) until Instana.agent.ready? || Time.now > deadline
abort('[otlp_http] Agent not ready after 15 s — is the Instana agent running?') unless Instana.agent.ready?

puts "[otlp_http] Agent ready — sending 5 spans via OTLP"

# ---------------------------------------------------------------------------
# 1. Basic span — minimal tracing, just a name
# ---------------------------------------------------------------------------
Instana.tracer.in_span('otlp.example.basic') do
  # Simulate work
  sleep(0.01)
end

# ---------------------------------------------------------------------------
# 2. HTTP exit span — outbound HTTP call with standard attributes
#
# Uses SpanKind::CLIENT (kind 2) so the OTLP converter maps this to an
# http.client span with url.full, http.request.method, http.response.status_code.
# ---------------------------------------------------------------------------
Instana.tracer.in_span(
  'GET',
  attributes: {
    'http.method' => 'GET',
    'http.url' => 'https://api.example.com/users/42',
    'http.status_code' => 200
  },
  kind: Instana::Trace::SpanKind::CLIENT
) do
  # Actual Net::HTTP call would go here
  sleep(0.01)
end

# ---------------------------------------------------------------------------
# 3. Database span — SQL query with sanitised statement
#
# Matches the activerecord / sequel span type. The database converter maps
# db.statement, db.system, and server.address to OTLP semantic conventions.
# ---------------------------------------------------------------------------
Instana.tracer.in_span(
  'activerecord',
  attributes: {
    'activerecord.sql' => 'SELECT "users".* FROM "users" WHERE "users"."id" = ?',
    'activerecord.adapter' => 'PostgreSQL'
  }
) do
  sleep(0.01)
end

# ---------------------------------------------------------------------------
# 4. Nested spans — parent / child relationship
#
# The child span captures the parent_span_id from SpanContext, which the
# OTLP exporter serialises into the parent_span_id field of the protobuf.
# ---------------------------------------------------------------------------
Instana.tracer.in_span('otlp.example.parent') do
  Instana.tracer.in_span('otlp.example.child') do
    sleep(0.01)
  end
end

# ---------------------------------------------------------------------------
# 5. Error span — exception recorded as an OTLP span event
#
# When ec (error count) > 0, BaseConverter#build_error_events generates an
# "exception" span event with exception.message and exception.stacktrace.
# The span status is set to ERROR.
# ---------------------------------------------------------------------------
begin
  Instana.tracer.in_span('otlp.example.error') do
    raise StandardError, 'Something went wrong in the OTLP example'
  end
rescue StandardError
  # Error is captured inside the span; rescue here to allow script to continue
end

# Allow the background timer to flush the span batch to the agent
sleep(10)

puts 'otlp_http.rb complete — check agent/Instana UI for 5 spans'
