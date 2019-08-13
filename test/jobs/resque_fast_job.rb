require "redis"
require "net/http"

class FastJob
  @queue = :critical

  def self.perform
    if ENV.key?('REDIS_URL')
      redis = Redis.new(ENV['REDIS_URL'])
    elsif ENV.key?('I_REDIS_URL')
      redis = Redis.new(ENV['I_REDIS_URL'])
    else
      redis = Redis.new('localhost:6379')
    end

    dt = Time.now
    redis.set('ts', dt)
    redis.set(:nb_id, 2)
  end
end
