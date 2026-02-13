#!/usr/bin/env bash
# entrypoint-wrapper.sh — Patch nginx config for Heroku (no browser sidecar)
# The coollabsio/openclaw image expects a "browser" sidecar container.
# On Heroku (single-container), this upstream doesn't exist, causing nginx
# to crash with: "host not found in upstream 'browser'"
#
# This script removes all browser-related blocks from the nginx config
# before handing off to the original entrypoint.
set -euo pipefail

NGINX_CONF="/etc/nginx/conf.d/openclaw.conf"

if [ -f "$NGINX_CONF" ]; then
  echo "[heroku-patch] Patching nginx config to remove browser sidecar references..."

  # Use perl for reliable multi-line block removal:
  # 1. Remove "upstream browser { ... }" blocks
  # 2. Remove "location" blocks containing "proxy_pass http://browser"
  perl -i -0777 -pe '
    # Remove upstream browser block
    s/upstream\s+browser\s*\{[^}]*\}\s*//gs;

    # Remove location blocks that proxy to browser
    s/location\s+[^\{]*\{[^}]*proxy_pass\s+http:\/\/browser[^}]*\}\s*//gs;
  ' "$NGINX_CONF"

  echo "[heroku-patch] Nginx config patched successfully."
else
  echo "[heroku-patch] No nginx config found at $NGINX_CONF, skipping patch."
fi

# Hand off to the original entrypoint
exec /app/scripts/entrypoint.sh "$@"
