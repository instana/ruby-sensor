# Hook into sidekiq to control the current mode

# (c) Copyright IBM Corp. 2021
# (c) Copyright Instana Inc. 2021

$sidekiq_mode = :client
class << Sidekiq
  def server?
    $sidekiq_mode == :server
  end
end

# Configure redis for sidekiq client
Sidekiq.configure_client do |config|
  config.redis = { url: ENV['REDIS_URL'] }
end

# Configure redis for sidekiq worker
$sidekiq_mode = :server
::Sidekiq.configure_server do |config|
  config.redis = { url: ENV['REDIS_URL'] }
end
$sidekiq_mode = :client

require_relative 'worker'
