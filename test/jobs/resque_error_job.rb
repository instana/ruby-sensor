require "redis"
require "net/http"

class ErrorJob
  @queue = :critical

  def self.perform
    if ENV.key?('REDIS_URL')
      redis = Redis.new(:url => ENV['REDIS_URL'])
    elsif ENV.key?('I_REDIS_URL')
      redis = Redis.new(:url => ENV['I_REDIS_URL'])
    else
      redis = Redis.new(:url => 'localhost:6379')
    end

    dt = Time.now
    redis.set('ts', dt)

    raise Exception.new("Silly Rabbit, Trix are for kids.")
    redis.set(:nb_id, 2)
  end
end
