#!/usr/bin/env bash
set -e

URL="https://www.spatialbrain.org"      # full public URL
NTFY_URL="https://ntfy.sh/laune" # or your self-hosted ntfy endpoint
CONTAINER_NAME="spatialbrain"               # docker container name (optional restart)

# Try to fetch the page (HTTP 2xx/3xx counts as OK)
if curl -fsS --max-time 10 -o /dev/null "$URL"; then
  exit 0
else
  MSG="Spatialbrain appears DOWN on $(hostname) at $(date -Iseconds). URL: $URL"
  # Send ntfy notification
  curl -d "$MSG" "$NTFY_URL" || true

  # OPTIONAL: try to restart the container
  if command -v docker >/dev/null 2>&1; then
    docker restart "$CONTAINER_NAME" >/dev/null 2>&1 || true
  fi
fi
