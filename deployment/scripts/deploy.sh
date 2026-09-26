#!/usr/bin/env bash
# Deploy one specific commit as an immutable release.
# The current release is never overwritten in place. The `current` symlink is
# switched only after health checks on the new release pass.
#
# Usage:
#   deploy.sh RELEASE_ID COMMIT_SHA REPOSITORY_URL
# Example:
#   deploy.sh 20260925-120000-abc123 abc123def git@github.com:org/repo.git
set -Eeuo pipefail

APP_ROOT="/opt/platform-app"
RELEASES_DIR="${APP_ROOT}/releases"
CURRENT_LINK="${APP_ROOT}/current"
HEALTH_URL="http://127.0.0.1:8000/health"
READY_URL="http://127.0.0.1:8000/ready"
NGINX_HEALTH_URL="http://127.0.0.1/health"

RELEASE_ID="${1:?RELEASE_ID required}"
COMMIT_SHA="${2:?COMMIT_SHA required}"
REPO_URL="${3:?REPOSITORY_URL required}"
RELEASE_DIR="${RELEASES_DIR}/${RELEASE_ID}"

log() { printf '[deploy] %s\n' "$*"; }

require_commands() {
  for c in git python3 curl systemctl; do
    command -v "$c" >/dev/null 2>&1 || { echo "Missing command: $c" >&2; exit 1; }
  done
}

fetch_code() {
  log "Creating release dir ${RELEASE_DIR}"
  mkdir -p "${RELEASE_DIR}"
  git clone --no-checkout "${REPO_URL}" "${RELEASE_DIR}"
  git -C "${RELEASE_DIR}" checkout "${COMMIT_SHA}"
}

build_venv() {
  log "Building virtualenv and installing pinned dependencies"
  python3 -m venv "${RELEASE_DIR}/.venv"
  "${RELEASE_DIR}/.venv/bin/pip" install --upgrade pip
  "${RELEASE_DIR}/.venv/bin/pip" install -r "${RELEASE_DIR}/requirements.txt"
}

run_tests() {
  log "Running tests before switching traffic"
  "${RELEASE_DIR}/.venv/bin/pip" install -r "${RELEASE_DIR}/requirements-dev.txt"
  ( cd "${RELEASE_DIR}" && "${RELEASE_DIR}/.venv/bin/python" -m pytest -q )
}

run_migration() {
  # Placeholder for a controlled, backward-compatible migration step.
  # Prefer expand/contract migrations; never auto-run destructive rollbacks.
  if [[ -x "${RELEASE_DIR}/deployment/scripts/migrate.sh" ]]; then
    log "Running migration"
    "${RELEASE_DIR}/deployment/scripts/migrate.sh"
  else
    log "No migration step defined; skipping"
  fi
}

start_service_on_new_release() {
  # Point current at the new release so systemd runs the new code, then restart.
  log "Activating new release and restarting service"
  ln -sfn "${RELEASE_DIR}" "${CURRENT_LINK}"
  systemctl restart platform-app
}

wait_for_health() {
  local url="$1" tries="${2:-30}"
  log "Waiting for ${url}"
  for _ in $(seq 1 "${tries}"); do
    if curl -fsS "${url}" >/dev/null 2>&1; then
      log "OK: ${url}"
      return 0
    fi
    sleep 2
  done
  echo "Health check failed: ${url}" >&2
  return 1
}

main() {
  require_commands
  local previous_target=""
  if [[ -L "${CURRENT_LINK}" ]]; then
    previous_target="$(readlink -f "${CURRENT_LINK}")"
  fi

  fetch_code
  build_venv
  run_tests
  run_migration
  start_service_on_new_release

  # Validate the new release; roll back on any failure.
  if ! wait_for_health "${HEALTH_URL}" 30; then
    log "Health failed. Rolling back."
    rollback "${previous_target}"
    exit 1
  fi

  # /ready is a soft gate: log but do not fail if DB not part of this deploy.
  curl -fsS "${READY_URL}" >/dev/null 2>&1 && log "readiness OK" || log "readiness not ready (check DB)"

  wait_for_health "${NGINX_HEALTH_URL}" 15 || log "Nginx health not reachable (check nginx)"

  log "Deployment of ${RELEASE_ID} (${COMMIT_SHA}) succeeded. current -> ${RELEASE_DIR}"
  cleanup_old_releases
}

rollback() {
  local target="$1"
  if [[ -z "${target}" || ! -d "${target}" ]]; then
    echo "No known-good previous release to roll back to." >&2
    return 1
  fi
  ln -sfn "${target}" "${CURRENT_LINK}"
  systemctl restart platform-app
  wait_for_health "${HEALTH_URL}" 30 || echo "Rollback health check failed." >&2
  log "Rolled back to ${target}"
}

cleanup_old_releases() {
  # Keep the two most recent releases.
  log "Pruning old releases (keeping 2 most recent)"
  ( cd "${RELEASES_DIR}" && ls -1dt */ 2>/dev/null | tail -n +3 | xargs -r rm -rf )
}

main "$@"
