class SidekiqJobOne
  include Sidekiq::Worker

  def perform(a, b, c)
  end
end
