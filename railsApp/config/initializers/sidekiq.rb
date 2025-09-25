require "sidekiq"
require "sidekiq-cron"

redis_url = ENV.fetch("REDIS_SIDEKIQ_URL") { ENV.fetch("REDIS_URL", "redis://redis:6379/1") }
Sidekiq.configure_server do |c|
  c.redis = { url: redis_url }

  # Load cron schedule on server boot
  schedule = {
    # “every hour at minute 12”
    "cleanup_finished_jobs" => {
      "cron"  => "12 * * * *",
      "class" => "CleanupFinishedJobsJob"
    }
  }
  Sidekiq::Cron::Job.load_from_hash(schedule)
end

Sidekiq.configure_client { |c| c.redis = { url: redis_url } }