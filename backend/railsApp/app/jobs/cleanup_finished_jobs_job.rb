class CleanupFinishedJobsJob < ApplicationJob
  queue_as :default

  def perform
    # Put your periodic maintenance here.
    # If you were clearing Solid Queue’s finished jobs, there’s no direct equivalent needed for Sidekiq.
    # Example placeholder:
    Rails.logger.info "[cron] CleanupFinishedJobsJob ran at #{Time.now.utc}"
  end
end
