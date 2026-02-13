#!/usr/bin/env bash
# deploy.sh — OpenClaw → Heroku Container Registry
# Usage: bash deploy.sh
# Prerequisites: heroku CLI, docker
set -euo pipefail

# ─── 載入 .env ───
ENV_FILE="${ENV_FILE:-.env}"
if [ -f "$ENV_FILE" ]; then
  echo "==> Loading env from $ENV_FILE"
  export $(grep -v '^#' "$ENV_FILE" | grep -v '^$' | xargs)
else
  echo "⚠️  No $ENV_FILE found, using existing environment variables"
fi

APP_NAME="${HEROKU_APP_NAME:-openclaw-$(whoami)}"

echo "==> Creating Heroku app: $APP_NAME"
heroku create "$APP_NAME" --stack container || echo "App already exists, continuing..."

# ─── Required: AI provider ───
OPENCLAW_GATEWAY_TOKEN="${OPENCLAW_GATEWAY_TOKEN:-$(openssl rand -hex 32)}"

echo "==> Setting required config vars"
heroku config:set -a "$APP_NAME" \
  OPENROUTER_API_KEY="$OPENROUTER_API_KEY" \
  AUTH_PASSWORD="$AUTH_PASSWORD" \
  AUTH_USERNAME="${AUTH_USERNAME:-admin}" \
  OPENCLAW_GATEWAY_TOKEN="$OPENCLAW_GATEWAY_TOKEN"

# ─── Optional: Telegram channel ───
if [ -n "${TELEGRAM_BOT_TOKEN:-}" ]; then
  echo "==> Configuring Telegram"
  heroku config:set -a "$APP_NAME" \
    TELEGRAM_BOT_TOKEN="$TELEGRAM_BOT_TOKEN" \
    TELEGRAM_DM_POLICY="${TELEGRAM_DM_POLICY:-pairing}"
fi

# ─── Optional: Discord channel ───
if [ -n "${DISCORD_BOT_TOKEN:-}" ]; then
  echo "==> Configuring Discord"
  heroku config:set -a "$APP_NAME" \
    DISCORD_BOT_TOKEN="$DISCORD_BOT_TOKEN" \
    DISCORD_DM_POLICY="${DISCORD_DM_POLICY:-pairing}"
fi

# ─── Optional: Slack channel ───
if [ -n "${SLACK_BOT_TOKEN:-}" ]; then
  echo "==> Configuring Slack"
  heroku config:set -a "$APP_NAME" \
    SLACK_BOT_TOKEN="$SLACK_BOT_TOKEN" \
    SLACK_APP_TOKEN="${SLACK_APP_TOKEN:-}" \
    SLACK_MODE="${SLACK_MODE:-socket}"
fi

# ─── Optional: Model override ───
if [ -n "${OPENCLAW_PRIMARY_MODEL:-}" ]; then
  echo "==> Setting model override"
  heroku config:set -a "$APP_NAME" \
    OPENCLAW_PRIMARY_MODEL="$OPENCLAW_PRIMARY_MODEL"
fi

echo "==> Deploying to Heroku (Container Registry)"
heroku container:login
heroku container:push web -a "$APP_NAME"
heroku container:release web -a "$APP_NAME"

echo ""
echo "==> Done! Your OpenClaw is at:"
echo "    https://$APP_NAME.herokuapp.com"
echo ""
echo "==> Login: admin / (your AUTH_PASSWORD)"
echo ""
echo "==> Useful commands:"
echo "    heroku logs --tail -a $APP_NAME"
echo "    heroku config -a $APP_NAME"
echo "    heroku ps -a $APP_NAME"
echo "    heroku ps:scale web=1:standard-1x -a $APP_NAME"
echo ""
echo "⚠️  IMPORTANT:"
echo "    1. Make sure .env has correct OPENROUTER_API_KEY"
echo "    2. Make sure .env has a strong AUTH_PASSWORD"
echo "    3. Scale to standard-1x to avoid dyno sleeping:"
echo "       heroku ps:scale web=1:standard-1x -a $APP_NAME"
echo "    4. Heroku filesystem is EPHEMERAL — dyno restart = state lost"
echo "       For persistence, see README.md"
