#!/usr/bin/env bash
# One-time server setup for platform-app.
# Installs packages, creates the service user and directory layout, installs
# the systemd unit and Nginx config template, and creates the env-file example.
# Contains NO secrets. Idempotent where practical.
set -Eeuo pipefail

APP_USER="platform"
APP_ROOT="/opt/platform-app"
ETC_DIR="/etc/platform-app"
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

log() { printf '[bootstrap] %s\n' "$*"; }

require_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    echo "Run as root (sudo)." >&2
    exit 1
  fi
}

install_packages() {
  if command -v dnf >/dev/null 2>&1; then
    log "Detected dnf (Amazon Linux 2023 / RHEL family)."
    dnf -y update
    dnf -y install python3 python3-pip nginx git postgresql15 curl
  elif command -v apt-get >/dev/null 2>&1; then
    log "Detected apt (Ubuntu/Debian family)."
    apt-get update
    apt-get upgrade -y
    apt-get install -y python3 python3-venv python3-pip nginx git postgresql-client curl
  else
    echo "No supported package manager found (dnf/apt)." >&2
    exit 1
  fi
}

create_user_and_dirs() {
  if ! id "${APP_USER}" >/dev/null 2>&1; then
    log "Creating service user ${APP_USER}."
    useradd --system --create-home --shell /usr/sbin/nologin "${APP_USER}"
  fi
  mkdir -p "${APP_ROOT}/releases" "${APP_ROOT}/shared" "${ETC_DIR}"
  chown -R "${APP_USER}:${APP_USER}" "${APP_ROOT}"
  chmod 750 "${ETC_DIR}"
}

install_systemd_unit() {
  log "Installing systemd unit."
  install -m 0644 "${REPO_DIR}/deployment/systemd/platform-app.service" \
    /etc/systemd/system/platform-app.service
  systemctl daemon-reload
  systemctl enable platform-app
}

install_nginx_conf() {
  log "Installing Nginx config template."
  install -m 0644 "${REPO_DIR}/deployment/nginx/platform-app.conf" \
    /etc/nginx/conf.d/platform-app.conf
  nginx -t
}

install_env_example() {
  if [[ ! -f "${ETC_DIR}/platform-app.env" ]]; then
    log "Installing env-file EXAMPLE (edit with real values, do not commit)."
    install -m 0640 "${REPO_DIR}/deployment/env/platform-app.env.example" \
      "${ETC_DIR}/platform-app.env"
    chown root:"${APP_USER}" "${ETC_DIR}/platform-app.env"
  fi
}

validate() {
  log "Validating installation."
  command -v python3 >/dev/null && log "python3 OK"
  command -v nginx >/dev/null && log "nginx OK"
  systemctl is-enabled platform-app >/dev/null && log "unit enabled OK"
}

main() {
  require_root
  install_packages
  create_user_and_dirs
  install_systemd_unit
  install_nginx_conf
  install_env_example
  validate
  log "Bootstrap complete. Edit ${ETC_DIR}/platform-app.env before deploying."
}

main "$@"
