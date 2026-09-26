#!/usr/bin/env bash
# Standalone health check usable by deploys, cron, or manual troubleshooting.
# Exits non-zero if the liveness endpoint is not healthy.
#
# Usage: health_check.sh [URL]
set -Eeuo pipefail

URL="${1:-http://127.0.0.1:8000/health}"
RETRIES="${RETRIES:-15}"
SLEEP="${SLEEP:-2}"

for i in $(seq 1 "${RETRIES}"); do
  if curl -fsS "${URL}" >/dev/null 2>&1; then
    echo "healthy: ${URL}"
    exit 0
  fi
  echo "attempt ${i}/${RETRIES} failed for ${URL}"
  sleep "${SLEEP}"
done

echo "unhealthy after ${RETRIES} attempts: ${URL}" >&2
exit 1
