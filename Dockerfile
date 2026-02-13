# OpenClaw — Heroku Container Stack
# Based on coollabsio/openclaw (pre-built, nginx + gateway)
FROM coollabsio/openclaw:latest

# Persist state (ephemeral on Heroku — use S3 for production)
VOLUME ["/data"]

# Patch: add wrapper entrypoint to remove browser sidecar references
# (Heroku is single-container, no browser sidecar available)
COPY entrypoint-wrapper.sh /app/scripts/entrypoint-wrapper.sh
RUN chmod +x /app/scripts/entrypoint-wrapper.sh

# Override entrypoint with our wrapper
ENTRYPOINT ["/app/scripts/entrypoint-wrapper.sh"]

# Health check (useful for local testing; Heroku ignores HEALTHCHECK)
HEALTHCHECK --interval=30s --timeout=5s --start-period=15s \
  CMD curl -sf http://localhost:${PORT:-8080}/healthz || exit 1

EXPOSE 8080
