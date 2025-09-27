# frozen_string_literal: true

require "net/http"
require "uri"
require "json"
require "jwt"

module Auth
  # Encapsulates fetching Supabase JWKS and validating JWT signatures/expirations.
  class JwtVerifier
    JWKS_CACHE_KEY = "auth.supabase.jwks".freeze
    JWKS_CACHE_TTL = 5.minutes

    class << self
      def verify!(token)
        raise Auth::ForbiddenError if token.blank?

        payload = case algorithm_for(token)
                  when "RS256"
                    verify_with_jwks(token)
                  when "HS256"
                    verify_with_secret(token)
                  else
                    raise Auth::ForbiddenError
                  end

        validate_claims!(payload)
        payload
      rescue JWT::DecodeError
        raise Auth::ForbiddenError
      end

      private

      def ensure_not_expired!(payload)
        expiration = payload["exp"]
        return if expiration && Time.at(expiration).future?

        raise Auth::ForbiddenError
      end

      def ensure_allowed_audience!(payload)
        token_audience = payload["aud"]
        return if token_audience.blank?

        audiences = Array(token_audience)
        raise Auth::ForbiddenError if (audiences & allowed_audiences).empty?
      end

      def ensure_expected_issuer!(payload)
        expected = expected_issuer
        return if expected.blank?

        raise Auth::ForbiddenError unless payload["iss"] == expected
      end

      def validate_claims!(payload)
        ensure_not_expired!(payload)
        ensure_allowed_audience!(payload)
        ensure_expected_issuer!(payload)
      end

      def algorithm_for(token)
        _payload, header = JWT.decode(token, nil, false)
        header["alg"]
      rescue StandardError
        raise Auth::ForbiddenError
      end

      def verify_with_jwks(token)
        payload, = JWT.decode(token, nil, true, algorithms: ["RS256"], jwks: jwks_set)
        payload
      end

      def verify_with_secret(token)
        secret = supabase_secret
        raise Auth::ForbiddenError if secret.blank?

        payload, = JWT.decode(token, secret, true, algorithm: "HS256")
        payload
      end

      def jwks_set
        # Clear memoized data when our manual timer says the JWKS set is stale.
        @jwks_set = nil if jwks_cache_stale?
        @jwks_set ||= JWT::JWK::Set.new(fetch_jwks)
      end

      def jwks_cache_stale?
        @jwks_cached_at && @jwks_cached_at < JWKS_CACHE_TTL.ago
      end

      def fetch_jwks
        # Use Rails.cache so multiple web workers reuse the same JWKS snapshot.
        jwks_hash = Rails.cache.fetch(JWKS_CACHE_KEY, expires_in: JWKS_CACHE_TTL) { download_jwks }
        @jwks_cached_at = Time.current
        jwks_hash
      end

      def download_jwks
        uri = URI.parse(jwks_url)
        response = Net::HTTP.get_response(uri)
        raise Auth::ForbiddenError unless response.is_a?(Net::HTTPSuccess)

        JSON.parse(response.body)
      rescue StandardError
        raise Auth::ForbiddenError
      end

      def jwks_url
        # Prefer a fully-qualified override URL, otherwise derive it from SUPABASE_URL.
        ENV.fetch("SUPABASE_JWKS_URL") do
          supabase_base = ENV.fetch("SUPABASE_URL")
          "#{supabase_base.chomp('/')}/auth/v1/keys"
        end
      end

      def supabase_secret
        ENV["SUPABASE_JWT_SECRET"] ||
          ENV["SUPABASE_ANON_KEY"] ||
          ENV["SUPABASE_PUBLISHABLE_KEY"] ||
          ENV["YOUR_SUPABASE_PUBLISHABLE_KEY"]
      end

      def allowed_audiences
        @allowed_audiences ||= begin
          values = ENV.fetch("SUPABASE_ALLOWED_AUD", "authenticated").split(",").map(&:strip).reject(&:blank?)
          values.empty? ? ["authenticated"] : values
        end
      end

      def expected_issuer
        explicit = ENV["SUPABASE_JWT_ISSUER"]
        return explicit if explicit.present?

        base = ENV["SUPABASE_URL"] || ENV["YOUR_SUPABASE_URL"]
        base ? "#{base.chomp('/')}/auth/v1" : nil
      end
    end
  end
end
