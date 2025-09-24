# syntax=docker/dockerfile:1
ARG RUBY_VERSION=3.4.0
ARG DEBIAN_FRONTEND=noninteractive

# ---------- build stage ----------
FROM ruby:${RUBY_VERSION}-slim AS build
WORKDIR /app

# Build deps for native gems (pg, nokogiri, etc.)
RUN apt-get update && apt-get install -y --no-install-recommends \
      build-essential git curl pkg-config libpq-dev \
    && rm -rf /var/lib/apt/lists/*

# Gem layer (best cache)
COPY Gemfile Gemfile.lock ./
# Ensure lock supports arm64 (Ampere)
RUN bundle lock --add-platform aarch64-linux || true
ENV BUNDLE_DEPLOYMENT=1 BUNDLE_WITHOUT="development test"
RUN bundle install --jobs=4 && rm -rf /usr/local/bundle/cache

# App code
COPY . .

# Precompile assets (skip if you don't have assets)
ENV RAILS_ENV=production
# Use a dummy secret so precompile doesn’t need the real master key
RUN SECRET_KEY_BASE_DUMMY=1 bundle exec rake assets:precompile || true

# ---------- runtime stage ----------
FROM ruby:${RUBY_VERSION}-slim
WORKDIR /app

# Runtime libs only
RUN apt-get update && apt-get install -y --no-install-recommends \
      libpq5 curl \
    && rm -rf /var/lib/apt/lists/*

COPY --from=build /usr/local/bundle /usr/local/bundle
COPY --from=build /app /app

# Drop privileges
RUN useradd -m app && chown -R app:app /app
USER app

ENV RAILS_ENV=production RACK_ENV=production BUNDLE_DEPLOYMENT=1
EXPOSE 3000
HEALTHCHECK --interval=30s --timeout=5s --retries=5 \
  CMD curl -fsS http://localhost:3000/health || exit 1

CMD ["bundle","exec","puma","-C","config/puma.rb"]