require "instana/rack"

module Instana
  module RodaPathTemplateExtractor
    module RequestMethods
      TERM = defined?(::Roda) ? ::Roda::RodaPlugins::Base::RequestMethods::TERM : Object
      
      def if_match(args, &blk)
        path = @remaining_path
        captures = @captures.clear
  
        if match_all(args)
          (env['INSTANA_PATH_TEMPLATE_FRAGMENTS'] ||= []).concat(named_args(args, blk))
          block_result(blk.(*captures))
          env['INSTANA_HTTP_PATH_TEMPLATE'] = env['INSTANA_PATH_TEMPLATE_FRAGMENTS']
            .join('/')
            .prepend('/')
          throw :halt, response.finish
        else
          @remaining_path = path
          false
        end
      end
      
      def named_args(args, blk)  
        parameters = blk.parameters      
        args.map do |a| 
          case a
          when String
            a
          when TERM
            nil
          else
            _, name = parameters.pop
            "{#{name}}"
          end
        end.compact
      end  
    end
  end
end

if defined?(::Roda)
  ::Instana.logger.debug "Instrumenting Roda"
  Roda.use ::Instana::Rack
  Roda.plugin ::Instana::RodaPathTemplateExtractor
end
