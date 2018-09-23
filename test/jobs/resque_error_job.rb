require "redis"
require "net/http"

class ErrorJob
  @queue = :critical

  def self.perform
    redis = Redis.new(url: ENV['REDIS_URL'])

    dt = Time.now
    redis.set('ts', dt)

    raise Exception.new("Silly Rabbit, Trix are for kids.")
    redis.set(:nb_id, 2)
  end
end
