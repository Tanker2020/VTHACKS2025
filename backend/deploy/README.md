This docker-compose setup runs the Rails app, a Python "agent" compute service, Sidekiq worker, and Redis.

Key points
- The compose files reference `../railsApp/.env.production` for configuration. Put your production env values there (or change the env_file path).
- The Python agent listens on port 5000 and exposes `/health` for healthchecks.

Required environment variables (in `backend/railsApp/.env.production`)
- RAILS_ENV=production
- RAILS_MASTER_KEY=... (from Rails credentials)
- SUPABASE_URL=...
- SUPABASE_SERVICE_ROLE_KEY=... (server-side key)
- RECEIVE_PASSWORD=... (exact string Rails and agent will use)
- SHARED_SECRET=... (HMAC secret used to compute X-Signature)
- ORACLE_URL=http://agent:5000/compute_and_send  # optional, agent sets this by default in compose

Optional / database
- DATABASE_URL=postgres://...  # if not provided, the app falls back to sqlite3 for local/dev convenience

Usage (development)
- From repository root:
  docker compose -f backend/deploy/docker-compose.dev.yml up --build

Notes
- The agent and rails share the same `.env.production` file in this setup for convenience; ensure secrets are kept safe.
- If you want Rails to wait for the agent before booting in production, keep the `depends_on` with healthcheck as configured in the prod compose.
