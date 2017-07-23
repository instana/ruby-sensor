class SidekiqJobTwo
  include Sidekiq::Worker

  def perform(a, b, c)
    raise 'Fail to execute the job'
  end
end
