# OpenClaw — Heroku Container Stack
# Based on coollabsio/openclaw (pre-built, nginx + gateway)
FROM coollabsio/openclaw:latest

# Persist state (ephemeral on Heroku — use S3 for production)
VOLUME ["/data"]

# Health check (useful for local testing; Heroku ignores HEALTHCHECK)
HEALTHCHECK --interval=30s --timeout=5s --start-period=15s \
  CMD curl -sf http://localhost:${PORT:-8080}/healthz || exit 1

EXPOSE 8080
