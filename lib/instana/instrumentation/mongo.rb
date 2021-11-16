# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2021

module Instana
  class Mongo
    REMOVED_COMMAND_ELEMENTS = %w[lsid $db documents].freeze

    def initialize
      @requests = {}
    end

    def started(event)
      tags = {
        namespace: event.database_name,
        command: event.command_name,
        peer: {
          hostname: event.address.host,
          port: event.address.port
        },
        json: filter_statement(event.command)
      }

      @requests[event.request_id] = ::Instana.tracer.log_async_entry(:mongo, {mongo: tags})
    end

    def failed(event)
      span = @requests.delete(event.request_id)
      span.add_error(Exception.new(event.message))

      ::Instana.tracer.log_async_exit(:mongo, {}, span)
    end

    def succeeded(event)
      span = @requests.delete(event.request_id)
      ::Instana.tracer.log_async_exit(:mongo, {}, span)
    end

    private

    def filter_statement(command)
      command.delete_if { |k, _| REMOVED_COMMAND_ELEMENTS.include?(k) }

      JSON.dump(command)
    end
  end
end
