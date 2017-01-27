
class EmailJob
  def perform
    @memcached_host = ENV['MEMCACHED_HOST'] || '127.0.0.1:11211'
    @dc = Dalli::Client.new(@memcached_host, :namespace => "instana_test")

    @dc.set(:one, 1)
    @dc.set(:three, 3)

    @dc.set(:instana, :rocks)
    @dc.get(:instana)
    @dc.set(:instana, :rocks)
    @dc.delete(:instana)
    @dc.get_multi(:one, :two, :three, :four)
  end
end
