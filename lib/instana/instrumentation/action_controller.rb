# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2021

module Instana
  module Instrumentation
    module ActionController
      def process_action(*args)
        call_payload = {
          actioncontroller: {
            controller: self.class.name,
            action: action_name
          }
        }

        request.env['INSTANA_HTTP_PATH_TEMPLATE'] = matched_path_template
        ::Instana::Tracer.trace(:actioncontroller, call_payload) { super(*args) }
      end

      def render(*args, &block)
        call_payload = {
          actionview: {
            name: describe_render_options(args.first) || 'Default'
          }
        }

        ::Instana::Tracer.trace(:actionview, call_payload) { super(*args, &block) }
      end

      private

      def matched_path_template
        Rails.application.routes.router.recognize(request) do |route, _, _|
          path = route.path
          return path.spec.to_s
        end

        nil
      end

      def describe_render_options(options)
        return unless options.is_a?(Hash)

        describe_layout(options[:layout]) ||
          describe_direct(options)
      end

      def describe_layout(layout)
        return unless layout

        case layout
        when FalseClass
          'Without layout'
        when String
          layout
        when Proc
          'Proc'
        else
          'Default'
        end
      end

      def describe_direct(options)
        case options
        when ->(o) { o.key?(:nothing) }
          'Nothing'
        when ->(o) { o.key?(:plain) }
          'Plaintext'
        when ->(o) { o.key?(:json) }
          'JSON'
        when ->(o) { o.key?(:xml) }
          'XML'
        when ->(o) { o.key?(:body) }
          'Raw'
        when ->(o) { o.key?(:js) }
          'Javascript'
        when ->(o) { o.key?(:template) }
          options[:template]
        when ->(o) { o.key?(:file) }
          options[:file]
        end
      end
    end
  end
end
