class SidekiqJobOne
  include Sidekiq::Worker

  def perform(a, b, c)
    @memcached_host = ENV['MEMCACHED_HOST'] || '127.0.0.1:11211'
    @dc = Dalli::Client.new(@memcached_host, :namespace => "instana_test")
    @dc.set(:job_one_result, 'done')
    @dc.set(:job_one_data, "data_#{a}_#{b}_#{c}")
  end
end
