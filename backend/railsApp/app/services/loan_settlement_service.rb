require "json"
require "time"

class LoanSettlementService
  WIN_OUTCOME = "won".freeze
  LOSS_OUTCOME = "lost".freeze
  BANK_DEFAULT = "defaulted".freeze
  BANK_PAID = "paid".freeze

  def initialize(client: Supabase::Client.new, oracle_client: OracleClient)
    @client = client
    @oracle_client = oracle_client
    @profile_cache = {}
  end

  def call
    loans = Array(fetch_active_loans)
    return if loans.empty?

    default_ids = []
    loans.each do |loan|
      begin
        result = process_loan(loan)
        default_ids.concat(Array(result[:default_ids])) if result.present?
      rescue => e
        Rails.logger.error "[LoanSettlementService] Failed to process loan #{loan['loan_id']}: #{e.class} #{e.message}"
        Rails.logger.debug { e.backtrace.join("\n") }
      end
    end

    refresh_nash_scores(default_ids.uniq.compact) if default_ids.present?
  end

  private

  def fetch_active_loans
    @client.get(
      "bank_market",
      "select" => "id,loan_id,lender_id,lendee_id,amount,created_at,bank_arrays,outcome",
      "outcome" => "eq.in_progress"
    )
  rescue Supabase::Error => e
    Rails.logger.error "[LoanSettlementService] Unable to fetch bank_market rows: #{e.message}"
    []
  end

  def process_loan(loan)
    request = fetch_request(loan["loan_id"])
    return {} unless request.present?

    due_at = compute_due_timestamp(loan["created_at"], request["end_time"])
    return {} unless due_at && due_at <= Time.now.utc

    defaulted = defaulted?(loan)
    settle_bank_market(loan, defaulted)
    bonus_for_lender = settle_investments(loan, defaulted)

    if defaulted
      { default_ids: [loan["lendee_id"]] }
    else
      apply_positive_nash_bonus(loan["lendee_id"], loan["amount"], bonus_for_lender)
      {}
    end
  end

  def fetch_request(request_id)
    rows = @client.get(
      "loan_req_market",
      "select" => "req_id,end_time,created_at",
      "req_id" => "eq.#{request_id}"
    )
    rows&.first
  rescue Supabase::Error => e
    Rails.logger.error "[LoanSettlementService] Unable to fetch loan_req_market #{request_id}: #{e.message}"
    nil
  end

  def compute_due_timestamp(created_at, end_time)
    created = parse_time(created_at)
    return nil unless created && end_time

    days = end_time.to_i
    created + days.days
  end

  def parse_time(value)
    return value if value.is_a?(Time)
    if Time.zone
      Time.zone.parse(value.to_s)
    else
      Time.parse(value.to_s)
    end
  rescue ArgumentError
    nil
  end

  def defaulted?(loan)
    outcome = loan["outcome"].to_s.downcase
    return true if outcome == BANK_DEFAULT
    return false if outcome == BANK_PAID

    prices = normalize_numeric_array(loan["bank_arrays"])
    return true if prices.present? && prices.last.to_f < 0.5

    false
  end

  def settle_bank_market(loan, defaulted)
    outcome_value = defaulted ? BANK_DEFAULT : BANK_PAID
    @client.patch(
      "bank_market",
      {
        outcome: outcome_value,
        done: true,
        down: true,
        settled_at: Time.now.utc.iso8601
      },
      "id" => "eq.#{loan['id']}"
    )
  rescue Supabase::Error => e
    Rails.logger.error "[LoanSettlementService] Failed to update bank_market #{loan['id']}: #{e.message}"
  end

  def settle_investments(loan, defaulted)
    investments = fetch_investments(loan["loan_id"])
    return 0.0 if investments.blank?

    lender_bonus_total = 0.0
    timestamp = Time.now.utc.iso8601

    investments.each do |inv|
      selection = inv["selection"].to_s.downcase
      shares = compute_shares(inv)
      amount = inv["amount"].to_f
      winning = defaulted ? selection == "no" : selection == "yes"

      if winning
        gross = shares
        investor_credit = gross * 0.9
        lender_bonus = gross * 0.1
        lender_bonus_total += lender_bonus

        profit = investor_credit - amount
        adjust_profile(inv["investor_id"], balance_delta: investor_credit, profit_delta: profit)
        update_investment(inv["id"], outcome: WIN_OUTCOME, profit_amount: profit, shares: shares, settled_at: timestamp)
      else
        loss = -amount
        adjust_profile(inv["investor_id"], balance_delta: 0, profit_delta: loss)
        update_investment(inv["id"], outcome: LOSS_OUTCOME, profit_amount: loss, shares: shares, settled_at: timestamp)
      end
    end

    apply_lender_bonus(loan["lender_id"], lender_bonus_total)
    lender_bonus_total
  end

  def fetch_investments(loan_id)
    @client.get(
      "investments",
      "select" => "id,investor_id,amount,selection,entry_price,shares",
      "loan_id" => "eq.#{loan_id}"
    )
  rescue Supabase::Error => e
    Rails.logger.error "[LoanSettlementService] Unable to fetch investments for #{loan_id}: #{e.message}"
    []
  end

  def compute_shares(investment)
    shares = investment["shares"]
    return shares.to_f if shares.present? && shares.to_f.positive?

    entry_price = investment["entry_price"].to_f
    entry_price = 0.5 if entry_price <= 0
    amount = investment["amount"].to_f
    return 0.0 if amount <= 0

    (amount / entry_price).round(6)
  end

  def update_investment(id, attrs)
    @client.patch("investments", attrs, "id" => "eq.#{id}")
  rescue Supabase::Error => e
    Rails.logger.error "[LoanSettlementService] Failed to update investment #{id}: #{e.message}"
  end

  def adjust_profile(user_id, balance_delta:, profit_delta:)
    return if user_id.blank?

    profile = fetch_profile(user_id)
    return unless profile

    new_balance = profile["balance"].to_f + balance_delta.to_f
    new_profits = profile["profits"].to_f + profit_delta.to_f

    @client.patch(
      "profiles",
      { balance: new_balance, profits: new_profits },
      "id" => "eq.#{user_id}"
    )
    profile["balance"] = new_balance
    profile["profits"] = new_profits
  rescue Supabase::Error => e
    Rails.logger.error "[LoanSettlementService] Failed to adjust profile #{user_id}: #{e.message}"
  end

  def apply_lender_bonus(lender_id, bonus)
    return if lender_id.blank? || bonus.to_f <= 0

    adjust_profile(lender_id, balance_delta: bonus, profit_delta: bonus)
  end

  def apply_positive_nash_bonus(lendee_id, loan_amount, lender_bonus)
    return if lendee_id.blank?

    return if lender_bonus.to_f <= 0

    amount = loan_amount.to_f
    return if amount <= 0

    ratio = (lender_bonus.to_f / amount).clamp(0.0, 1.0)
    increment = (0.01 + (0.08 * ratio)).clamp(0.01, 0.09)

    profile = fetch_profile(lendee_id)
    return unless profile

    new_score = profile["nashScore"].to_f + increment
    @client.patch(
      "profiles",
      { nashScore: new_score },
      "id" => "eq.#{lendee_id}"
    )
    profile["nashScore"] = new_score
  rescue Supabase::Error => e
    Rails.logger.error "[LoanSettlementService] Failed to bump nashScore for #{lendee_id}: #{e.message}"
  end

  def fetch_profile(user_id)
    @profile_cache[user_id] ||= begin
      rows = @client.get(
        "profiles",
        "select" => "id,balance,profits,nashScore",
        "id" => "eq.#{user_id}"
      )
      rows&.first
    rescue Supabase::Error => e
      Rails.logger.error "[LoanSettlementService] Unable to fetch profile #{user_id}: #{e.message}"
      nil
    end
  end

  def refresh_nash_scores(default_ids)
    response = @oracle_client.post_uuids(default_ids)
    return if response[:code].to_i >= 400
    mapping = parse_mapping(response[:body])
    return if mapping.blank?

    mapping.each do |uuid, score|
      next if uuid.blank?

      begin
        @client.patch(
          "profiles",
          { nashScore: score.to_f },
          "id" => "eq.#{uuid}"
        )
        if @profile_cache[uuid]
          @profile_cache[uuid]["nashScore"] = score.to_f
        end
      rescue Supabase::Error => e
        Rails.logger.error "[LoanSettlementService] Failed to update nashScore for #{uuid}: #{e.message}"
      end
    end
  rescue => e
    Rails.logger.error "[LoanSettlementService] Failed to refresh nash scores: #{e.class} #{e.message}"
  end

  def parse_mapping(body)
    parsed = JSON.parse(body)
    if parsed.is_a?(Hash) && parsed["mapping"].is_a?(Hash)
      parsed["mapping"]
    elsif parsed.is_a?(Hash)
      parsed
    else
      {}
    end
  rescue JSON::ParserError
    {}
  end

  def normalize_numeric_array(raw)
    case raw
    when Array
      raw.map(&:to_f)
    when String
      JSON.parse(raw).map(&:to_f)
    else
      []
    end
  rescue JSON::ParserError
    []
  end
end
