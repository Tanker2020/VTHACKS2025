# frozen_string_literal: true

require "redis"
require "json"

module Auth
  # Wrapper that centralizes reading/writing JWT payloads to Redis for fast lookups.
  class TokenCache
    CACHE_NAMESPACE = "graphql:jwt".freeze

    class << self
      def fetch(token)
        # Tokens are stored with the raw JWT as the cache key, making lookups a single Redis call.
        raw_payload = redis.get(redis_key(token))
        raw_payload ? JSON.parse(raw_payload) : nil
      end

      def store(token, payload, expiry_epoch)
        ttl = [expiry_epoch.to_i - Time.now.to_i, 0].max
        return if ttl.zero?

        redis.set(redis_key(token), payload.to_json, ex: ttl)
      end

      def delete(token)
        redis.del(redis_key(token))
      end

      private

      def redis
        # Reuse a single Redis client so we do not flood the server with new connections per request.
        @redis ||= Redis.new(url: redis_url)
      end

      def redis_url
        ENV.fetch("REDIS_CACHE_URL") { ENV.fetch("REDIS_URL", "redis://localhost:6379/0") }
      end

      def redis_key(token)
        "#{CACHE_NAMESPACE}:#{token}"
      end
    end
  end
end
