require "instana/rack"

if defined?(::Camping)
  module Nuts
    use ::Instana::Rack
  end
end
