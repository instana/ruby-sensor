# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2016

require "instana/rack"

module Instana
  module CubaPathTemplateExtractor
    REPLACE_TARGET = /:(?<term>[^\/]+)/i

    def self.prepended(base)
      ::Instana.logger.debug "#{base} prepended #{self}"
    end

    def on(*args, &blk)
      wrapper = lambda do |*caputres|
        env['INSTANA_PATH_TEMPLATE_FRAGMENTS'] << args
          .select { |a| a.is_a?(String) }
          .join('/')

        blk.call(*captures)
      end

      super(*args, &wrapper)
    end

    def call!(env)
      env['INSTANA_PATH_TEMPLATE_FRAGMENTS'] = []
      response = super(env)
      env['INSTANA_HTTP_PATH_TEMPLATE'] = env['INSTANA_PATH_TEMPLATE_FRAGMENTS']
        .join('/')
        .gsub(REPLACE_TARGET, '{\k<term>}')
      response
    end
  end
end
