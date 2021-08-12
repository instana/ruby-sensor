# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2018

require "redis"
require "net/http"

class FastJob
  @queue = :critical

  def self.perform(*args)
    raise 'Invalid Args' unless args.empty?

    if ENV.key?('REDIS_URL')
      redis = Redis.new(:url => ENV['REDIS_URL'])
    else
      redis = Redis.new(:url => 'redis://localhost:6379')
    end

    dt = Time.now
    redis.set('ts', dt)
    redis.set(:nb_id, 2)
  end
end
