class ReceiveController < ApplicationController
  # Skip protections that would block service-to-service posts (adjust as needed)
  protect_from_forgery with: :null_session

  # Expected headers:
  # - X-Signature: sha256=<hex>
  # - Password: <shared password>

  def create
    raw = request.raw_post.to_s

    # Check password header
    expected_password = ENV.fetch('RECEIVE_PASSWORD', 'q7V;{X$og<^);g{&THeaB07u+-4-NPs{Hm4uMn*~6')
    incoming_password = request.headers['Password'] || request.headers['HTTP_PASSWORD']

    unless ActiveSupport::SecurityUtils.secure_compare((incoming_password || ''), expected_password)
      render json: { ok: false, message: 'invalid password' }, status: :unauthorized and return
    end

    # Verify signature if present
    signature = request.headers['X-Signature'] || request.headers['HTTP_X_SIGNATURE']
    shared_secret = ENV.fetch('SHARED_SECRET', 'dev-secret')

    if signature.present?
      unless verify_signature(raw, signature, shared_secret)
        render json: { ok: false, message: 'invalid signature' }, status: :unauthorized and return
      end
    end

    begin
      payload = JSON.parse(raw)
    rescue JSON::ParserError
      render json: { ok: false, message: 'invalid json' }, status: :bad_request and return
    end

    # Expect payload to be mapping or to include mapping key
    mapping = payload['mapping'] || payload

    # TODO: process mapping - save to DB, enqueue job, etc.
    Rails.logger.info "Received mapping for #{mapping.keys.length} uuids"

    render json: { ok: true, received: mapping.keys.length }
  end

  private

  def verify_signature(raw, header_sig, secret)
    # header_sig expected like: "sha256=<hex>"
    return false if header_sig.blank?
    alg, hex = header_sig.split('=', 2)
    return false unless alg == 'sha256' && hex.present?

    computed = OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha256'), secret.to_s, raw)
    ActiveSupport::SecurityUtils.secure_compare(computed, hex)
  end
end
