#!/usr/bin/env bash
# One-time setup: create .env, pull the image, onboard, start the Gateway.
set -euo pipefail
cd "$(dirname "$0")"

mkdir -p config workspace secrets

if [[ ! -f .env ]]; then
  cp .env.example .env
  echo "==> Created .env from .env.example"
fi

# Generate a Gateway token once and keep it in .env.
if ! grep -qE '^OPENCLAW_GATEWAY_TOKEN=.+' .env; then
  token="$(openssl rand -hex 32)"
  if grep -q '^OPENCLAW_GATEWAY_TOKEN=' .env; then
    sed -i.bak "s/^OPENCLAW_GATEWAY_TOKEN=.*/OPENCLAW_GATEWAY_TOKEN=${token}/" .env && rm -f .env.bak
  else
    echo "OPENCLAW_GATEWAY_TOKEN=${token}" >> .env
  fi
  echo "==> Generated Gateway token in .env"
fi

set -a; source .env; set +a
port="${OPENCLAW_GATEWAY_PORT:-18789}"

prestart() {
  docker compose run --rm --no-deps "$@"
}

# Pre-start commands write config directly, so make sure no Gateway holds the lock.
docker compose stop openclaw-gateway >/dev/null 2>&1 || true

echo "==> Pulling ${OPENCLAW_IMAGE:-ghcr.io/openclaw/openclaw:latest}"
docker compose pull openclaw-gateway

echo "==> Fixing folder ownership for the container user (uid 1000)"
prestart --user root --entrypoint sh openclaw-gateway -c \
  'chown node:node /home/node/.openclaw /home/node/.openclaw/workspace /home/node/.config/openclaw && \
   find -P /home/node/.openclaw -xdev \( ! -path /home/node/.openclaw/workspace -o -prune \) -execdir chown -h node:node {} + && \
   find -P /home/node/.config/openclaw -xdev -execdir chown -h node:node {} +'

if [[ -z "${OPENCLAW_SKIP_ONBOARDING:-}" ]]; then
  echo "==> Onboarding (interactive: choose your model provider)"
  prestart --entrypoint node openclaw-gateway dist/index.js onboard \
    --mode local \
    --no-install-daemon \
    --gateway-auth token \
    --gateway-token-ref-env OPENCLAW_GATEWAY_TOKEN \
    --skip-ui \
    --suppress-gateway-token-output
fi

echo "==> Applying Docker Gateway defaults"
prestart --entrypoint node openclaw-gateway dist/index.js config set --batch-json \
  "[{\"path\":\"gateway.mode\",\"value\":\"local\"},{\"path\":\"gateway.bind\",\"value\":\"lan\"},{\"path\":\"gateway.controlUi.allowedOrigins\",\"value\":[\"http://localhost:${port}\",\"http://127.0.0.1:${port}\"]}]" \
  >/dev/null

echo "==> Starting Gateway"
docker compose up -d openclaw-gateway

echo ""
echo "Done. Open http://127.0.0.1:${port}/ and paste OPENCLAW_GATEWAY_TOKEN from .env into Settings."
