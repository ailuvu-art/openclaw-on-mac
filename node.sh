#!/usr/bin/env bash
# Manage the paired openclaw-node container.
# Usage: ./node.sh start|stop|restart|status|logs|check|unpair
set -euo pipefail
cd "$(dirname "$0")"

compose() {
  docker compose --profile node "$@"
}

paired() {
  [[ -d node-state/state ]]
}

case "${1:-}" in
  start)
    if ! paired; then
      echo "Node is not paired yet. Run: ./pair-node.sh '<join-url>'" >&2
      exit 1
    fi
    compose up -d openclaw-node
    ;;
  stop)
    compose stop openclaw-node
    ;;
  restart)
    compose up -d --force-recreate openclaw-node
    ;;
  status)
    compose ps -a openclaw-node
    echo ""
    compose logs --tail 5 openclaw-node 2>/dev/null || true
    ;;
  logs)
    compose logs -f --tail 50 openclaw-node
    ;;
  check)
    # Checks that the Cloudflare service token passes Access, without using a join code.
    [[ -f .env ]] || { echo "No .env file." >&2; exit 1; }
    set -a; source .env; set +a
    url="${OPENCLAW_REMOTE_GATEWAY:-https://oc.nolanng.tech}"
    code="$(curl -s -o /dev/null -w '%{http_code}' \
      -H "CF-Access-Client-Id: ${CF_ACCESS_CLIENT_ID:-}" \
      -H "CF-Access-Client-Secret: ${CF_ACCESS_CLIENT_SECRET:-}" \
      "${url}/j/AAAAAAAAAAAAAAAAAAAAAA")"
    case "$code" in
      404) echo "OK ($code): the token passes Cloudflare Access." ;;
      403) echo "FAIL ($code): token recognised, but no Service Auth policy allows it." ;;
      302) echo "FAIL ($code): token missing or invalid; Access redirects to login." ;;
      *)   echo "Unexpected HTTP $code from ${url}." ;;
    esac
    ;;
  unpair)
    read -r -p "Remove the node container and its device token in ./node-state? [y/N] " answer
    [[ "$answer" == [yY] ]] || exit 0
    compose rm -sf openclaw-node
    docker compose --profile node run --rm --no-deps --user root --entrypoint sh openclaw-node \
      -c 'find /home/node/.openclaw -mindepth 1 ! -name .gitkeep -delete'
    echo "Local node state removed. Also remove the device on the Gateway (Control UI -> Devices)."
    ;;
  *)
    echo "Usage: $0 start|stop|restart|status|logs|check|unpair" >&2
    exit 1
    ;;
esac
