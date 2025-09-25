redis_url = ENV.fetch("REDIS_SIDEKIQ_URL") { ENV.fetch("REDIS_URL") }
Sidekiq.configure_server { |c| c.redis = { url: redis_url } }
Sidekiq.configure_client { |c| c.redis = { url: redis_url } }