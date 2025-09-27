# frozen_string_literal: true

module Types
  class MutationType < Types::BaseObject
    description "Root mutation type for GraphQL entrypoints"

    field :authenticate, Types::AuthPayloadType, null: false do
      description "Validates a Supabase JWT and returns its expiry when accepted"
      argument :token, String, required: false,
               description: "JWT to validate. Falls back to Authorization header when omitted"
    end

    def authenticate(token: nil)
      resolved_token = token.presence || context[:raw_jwt]
      raise Auth::ForbiddenError if resolved_token.blank?

      payload = fetch_payload(resolved_token)

      { expires_at: Time.at(payload.fetch("exp")).utc }
    end

    private

    # Favor the cached result when available, otherwise fall back to a full verification round trip.
    def fetch_payload(token)
      cached_payload = Auth::TokenCache.fetch(token)
      return cached_payload if cached_payload && fresh?(cached_payload)

      new_payload = Auth::JwtVerifier.verify!(token)
      Auth::TokenCache.store(token, new_payload, new_payload.fetch("exp"))
      new_payload
    end

    # Keep the TTL check close to the resolver so the intent is obvious when revisiting the code later.
    def fresh?(payload)
      expiration_epoch = payload["exp"].to_i
      expiration_epoch.positive? && expiration_epoch > Time.now.to_i
    end
  end
end
