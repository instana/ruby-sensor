begin
  require 'oj'
rescue LoadError => e
  # OJ is not available in JRuby
  module Instana
    class Oj
      def self.dump(*args)
        args.first.to_json
      end

      def self.load(*args)
        JSON.parse args.first
      end
    end
  end
end
