# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2018

require "redis"
require "net/http"

class ErrorJob
  @queue = :critical

  def self.perform
    if ENV.key?('REDIS_URL')
      redis = Redis.new(:url => ENV['REDIS_URL'])
    else
      redis = Redis.new(:url => 'localhost:6379')
    end

    dt = Time.now
    redis.set('ts', dt)

    raise Exception.new("Silly Rabbit, Trix are for kids.")
  end
end
