#!/usr/bin/env bash
set -euo pipefail
API="${LINKLAB_API:-http://localhost:8080}"

usage() {
  echo "Uso: linklab [shorten|stats|health] [args]" >&2
  exit 1
}

cmd=${1:-}
case "$cmd" in
  shorten)
    url=${2:-}
    [[ -z "$url" ]] && usage
    curl -s -X POST "$API/shorten" \
      -H "Content-Type: application/json" \
      -d "{\"url\": \"$url\"}" | jq .
    ;;
  stats)
    code=${2:-}
    [[ -z "$code" ]] && usage
    curl -s "$API/stats/$code" | jq .
    ;;
  health)
    curl -s "$API/health"
    ;;
  *)
    usage
    ;;
esac
