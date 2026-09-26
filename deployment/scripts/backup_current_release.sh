#!/usr/bin/env bash
# Record metadata about the current release before a deployment so it is easy
# to identify the known-good rollback target. Does not touch the database.
#
# Usage: backup_current_release.sh
set -Eeuo pipefail

APP_ROOT="/opt/platform-app"
CURRENT_LINK="${APP_ROOT}/current"
SHARED_DIR="${APP_ROOT}/shared"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="${SHARED_DIR}/last-known-good-${STAMP}.txt"

mkdir -p "${SHARED_DIR}"

if [[ -L "${CURRENT_LINK}" ]]; then
  TARGET="$(readlink -f "${CURRENT_LINK}")"
  {
    echo "timestamp_utc=${STAMP}"
    echo "release_dir=${TARGET}"
    if [[ -d "${TARGET}/.git" ]]; then
      echo "commit_sha=$(git -C "${TARGET}" rev-parse HEAD 2>/dev/null || echo unknown)"
    fi
  } > "${OUT}"
  echo "Recorded current release metadata to ${OUT}"
else
  echo "No current release symlink present; nothing to record." >&2
fi
