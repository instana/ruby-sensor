require "redis"
require "net/http"

class FastJob
  @queue = :critical

  def self.perform
    redis = Redis.new(url: ENV['REDIS_URL'])

    dt = Time.now
    redis.set('ts', dt)
    redis.set(:nb_id, 2)
  end
end
