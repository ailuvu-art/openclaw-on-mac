#!/usr/bin/env bash
# Pair the openclaw-node container to a remote OpenClaw Gateway.
# Usage: ./pair-node.sh <join-url>     (from `openclaw devices join-code` on the Gateway)
set -euo pipefail
cd "$(dirname "$0")"

target="${1:-}"
if [[ -z "$target" ]]; then
  read -r -s -p "Paste the join URL: " target
  echo
fi
if [[ -z "$target" ]]; then
  echo "No join URL given." >&2
  exit 1
fi

[[ -f .env ]] || cp .env.example .env
set -a; source .env; set +a

if [[ "$target" == https://* && ( -z "${CF_ACCESS_CLIENT_ID:-}" || -z "${CF_ACCESS_CLIENT_SECRET:-}" ) ]]; then
  echo "Warning: CF_ACCESS_CLIENT_ID / CF_ACCESS_CLIENT_SECRET are empty in .env."
  echo "         A Gateway behind Cloudflare Access will reject the join request."
fi

mkdir -p node-state workspace

echo "==> Pulling ${OPENCLAW_NODE_IMAGE:-ghcr.io/openclaw/openclaw:latest}"
docker compose --profile node pull openclaw-node

# Hand the single-use join URL to the container through a private file;
# the node deletes it after reading, so it never appears in process args.
# Remove any old node container; a stale one can point at a deleted network.
docker compose --profile node rm -sf openclaw-node >/dev/null 2>&1 || true
umask 077
printf '%s\n' "$target" > node-state/join-target

echo "==> Fixing folder ownership for the container user (uid 1000)"
docker compose --profile node run --rm --no-deps --user root --entrypoint sh openclaw-node -c \
  'chown node:node /home/node/.openclaw /workspace && \
   find -P /home/node/.openclaw -xdev -execdir chown -h node:node {} +'

echo "==> Starting node"
docker compose --profile node up -d --force-recreate openclaw-node

echo ""
echo "Node started. Watch it with:  docker compose logs -f openclaw-node"
echo "Then approve it on the Gateway: openclaw nodes pending / openclaw nodes approve <id>"
