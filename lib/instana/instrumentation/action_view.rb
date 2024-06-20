# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2021

module Instana
  module Instrumentation
    module ActionView
      module PartialRenderer
        def render_partial(*args)
          call_payload = {
            render: {
              type: :partial,
              name: @options.is_a?(Hash) ? @options[:partial].to_s : 'Unknown'
            }
          }

          ::Instana::Tracer.trace(:render, call_payload) { super(*args) }
        end

        def render_collection(*args)
          call_payload = {
            render: {
              type: :collection,
              name: @path.to_s
            }
          }

          ::Instana::Tracer.trace(:render, call_payload) { super(*args) }
        end

        def render_partial_template(*args)
          call_payload = {
            render: {
              type: :partial,
              name:  @options.is_a?(Hash) ? @options[:partial].to_s : 'Unknown'
            }
          }

          ::Instana::Tracer.trace(:render, call_payload) { super(*args) }
        end
      end
      module CollectionRenderer
        def render_collection(*args)
          call_payload = {
            render: {
              type: :collection,
              name: @options.is_a?(Hash) ? @options[:partial].to_s : 'Unknown'
            }
          }

          ::Instana::Tracer.trace(:render, call_payload) { super(*args) }
        end
      end
    end
  end
end
