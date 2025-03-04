# (c) Copyright IBM Corp. 2025
# (c) Copyright Instana Inc. 2025

module Instana
  # Type of span. Can be used to specify additional relationships between spans in addition to a
  # parent/child relationship. For API ergonomics, use of the symbols rather than the constants
  # may be preferred. For example:
  #
  #   span = tracer.on_start('op', kind: :client)
  module SpanKind
    # Default value. Indicates that the span is used internally.
    INTERNAL = :internal

    # Indicates that the span covers server-side handling of an RPC or other remote request.
    SERVER = :server

    # Indicates that the span covers the client-side wrapper around an RPC or other remote request.
    CLIENT = :client

    # Indicates that the span describes producer sending a message to a broker. Unlike client and
    # server, there is no direct critical path latency relationship between producer and consumer
    # spans.
    PRODUCER = :producer

    # Indicates that the span describes consumer receiving a message from a broker. Unlike client
    # and server, there is no direct critical path latency relationship between producer and
    # consumer spans.
    CONSUMER = :consumer

    # Indicates an entry span. Equivalant to Server or Consumer
    ENTRY = :entry

    # Indicates an exit span. Equivalant to Client or Producer
    EXIT = :exit

    # Indicates an intermediate span. This used when sdk is used to produce intermediate traces
    INTERMEDIATE = :intermediate
  end
end
