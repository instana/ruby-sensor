# frozen_string_literal: true

module Instana
  module TestHelpers
    # Used to reset the gem to boot state.  It clears out any queued and/or staged
    # traces and resets the tracer to no active trace.
    #
    def clear_all!
      ::Instana.processor.clear!
      ::Instana.tracer.clear!
      nil
    end

    def disable_redis_instrumentation
      ::Instana.config[:redis][:enabled] = false
    end

    def enable_redis_instrumentation
      ::Instana.config[:redis][:enabled] = true
    end

    def validate_sdk_span(json_span, sdk_hash = {}, errored = false, _ec = 1)
      assert_equal :sdk, json_span[:n]
      assert json_span.key?(:k)
      assert json_span.key?(:d)
      assert json_span.key?(:ts)

      sdk_hash.each do |k, v|
        assert_equal v, json_span[:data][:sdk][k]
      end

      return unless errored

      assert_equal true, json_span[:error]
      assert_equal 1, json_span[:ec]
    end

    def find_spans_by_name(spans, name)
      spans.select do |span|
        (span[:n] == :sdk && span[:data][:sdk][:name] == name) || span[:n] == name
      end.tap do |result|
        raise StandardError, "No SDK spans (#{name}) could be found" if result.empty?
      end
    end

    def find_first_span_by_name(spans, name)
      spans.each do |span|
        case span[:n]
        when :sdk
          return span if span[:data][:sdk][:name] == name
        when name
          return span
        end
      end
      raise StandardError, "Span (#{name}) not found"
    end

    def find_span_by_id(spans, id)
      spans.each do |span|
        return span if span[:s] == id
      end
      raise StandardError, "Span with id (#{id}) not found"
    end

    # Finds the first span in +spans+ for which +block+ returns true
    #
    #     ar_span = find_first_span_by_qualifier(ar_spans) do |span|
    #       span[:data][:activerecord][:sql] == sql
    #     end
    #
    # This helper will raise an exception if no span evaluates to true against he provided block.
    #
    # +spans+: +Array+ of spans to search
    # +block+: The Ruby block to evaluate against each span
    def find_first_span_by_qualifier(spans, &block)
      spans.each do |span|
        return span if block.call(span)
      end
      raise StandardError, 'Span with qualifier not found'
    end

    def has_postgres_database?
      URI(ENV.fetch('DATABASE_URL', '')).scheme == 'postgres'
    end

    def has_mysql2_database?
      URI(ENV.fetch('DATABASE_URL', '')).scheme == 'mysql2'
    end

    def has_mysql_database?
      URI(ENV.fetch('DATABASE_URL', '')).scheme == 'mysql'
    end
  end
end
