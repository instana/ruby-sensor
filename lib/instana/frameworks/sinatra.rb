# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2016

require "instana/rack"

# This instrumentation will insert Rack into Sinatra _and_ Padrino since
# the latter is based on Sinatra

module Instana
  module SinatraPathTemplateExtractor
    def self.extended(base)
      base.store_path_template
    end

    def store_path_template
      after do
        @env["INSTANA_HTTP_PATH_TEMPLATE"] = @env["sinatra.route"]
          .sub("#{@request.request_method} ", '')
      end
    end
  end
end
