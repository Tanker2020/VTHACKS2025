require "sidekiq"
require "sidekiq-cron"

redis_url = ENV.fetch("REDIS_SIDEKIQ_URL") { ENV.fetch("REDIS_URL", "redis://redis:6379/1") }
Sidekiq.configure_server do |c|
  c.redis = { url: redis_url }

  # Load cron schedule on server boot
  schedule = {
    "loan_settlement_job" => {
      "cron"  => "*/20 * * * *",
      "class" => "LoanSettlementJob",
      "queue" => "default"
    }
  }
  Sidekiq::Cron::Job.load_from_hash(schedule)
end

Sidekiq.configure_client { |c| c.redis = { url: redis_url } }
