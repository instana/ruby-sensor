require "redis"
require "net/http"

class FastJob
  @queue = :critical

  def self.perform
    if ENV.key?('REDIS_URL')
      redis = Redis.new(:url => ENV['REDIS_URL'])
    elsif ENV.key?('REDIS_URL')
      redis = Redis.new(:url => ENV['REDIS_URL'])
    else
      redis = Redis.new(:url => 'redis://localhost:6379')
    end

    dt = Time.now
    redis.set('ts', dt)
    redis.set(:nb_id, 2)
  end
end
