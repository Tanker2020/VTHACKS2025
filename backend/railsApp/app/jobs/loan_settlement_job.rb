class LoanSettlementJob < ApplicationJob
  queue_as :default

  def perform
    LoanSettlementService.new.call
  rescue => e
    Rails.logger.error "[LoanSettlementJob] #{e.class}: #{e.message}"
    Rails.logger.debug { e.backtrace.join("\n") }
  end
end

