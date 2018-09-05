class ResqueWorkerJob1
  @queue = :normal

  def self.perform(*args)
    rc = Redis.new(url: ENV['REDIS_URL'])

    rc.set('hello', 'world')
    rc.set('hello', 'paramount')
    rc.set('other', 'hello')
  end
end
