# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2021

module Instana
  module Snapshot
    # @since 1.197.0
    module Deltable
      def delta(key, *rest, compute:, obj:, path: [key, *rest])
        val = obj[key]
        return val if val == nil

        if rest.empty?
          @__delta ||= Hash.new(0)
          cache_key = path.join('.')
          old = @__delta[cache_key]
          @__delta[cache_key] = val

          return compute.call(old, val)
        end

        delta(*rest, compute: compute, obj: val, path: path)
      end
    end
  end
end
