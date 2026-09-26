#!/usr/bin/env bash
# Roll back to a specific known-good release by switching the current symlink.
# Does NOT delete anything.
#
# Usage: rollback.sh TARGET_RELEASE
set -Eeuo pipefail

APP_ROOT="/opt/platform-app"
RELEASES_DIR="${APP_ROOT}/releases"
CURRENT_LINK="${APP_ROOT}/current"
HEALTH_URL="http://127.0.0.1:8000/health"
NGINX_HEALTH_URL="http://127.0.0.1/health"

TARGET_RELEASE="${1:?TARGET_RELEASE required}"
TARGET_DIR="${RELEASES_DIR}/${TARGET_RELEASE}"

log() { printf '[rollback] %s\n' "$*"; }

main() {
  [[ -d "${TARGET_DIR}" ]] || { echo "Target release not found: ${TARGET_DIR}" >&2; exit 1; }
  [[ -f "${TARGET_DIR}/wsgi.py" ]] || { echo "Target release missing wsgi.py" >&2; exit 1; }
  [[ -x "${TARGET_DIR}/.venv/bin/gunicorn" ]] || { echo "Target release missing gunicorn venv" >&2; exit 1; }

  log "Switching current -> ${TARGET_DIR}"
  ln -sfn "${TARGET_DIR}" "${CURRENT_LINK}"
  systemctl restart platform-app

  log "Verifying localhost health"
  for _ in $(seq 1 30); do
    curl -fsS "${HEALTH_URL}" >/dev/null 2>&1 && break
    sleep 2
  done
  curl -fsS "${HEALTH_URL}" >/dev/null 2>&1 || { echo "Health check failed after rollback." >&2; exit 1; }

  curl -fsS "${NGINX_HEALTH_URL}" >/dev/null 2>&1 && log "Nginx health OK" || log "Nginx health not reachable"

  log "Rollback complete. Active release: $(readlink -f "${CURRENT_LINK}")"
}

main "$@"
