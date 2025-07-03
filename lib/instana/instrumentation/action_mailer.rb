# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2021

module Instana
  module Instrumentation
    module ActionMailer
      def method_missing(method_name, *args) # rubocop:disable Style/MissingRespondToMissing
        if action_methods.include?(method_name.to_s)
          tags = {
            actionmailer: {
              class: to_s,
              method: method_name.to_s
            }
          }
          Instana.tracer.in_span(:'mail.actionmailer', attributes: tags) { super }
        else
          super
        end
      end
    end
  end
end
