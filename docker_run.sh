#!/usr/bin/env bash
set -euo pipefail

if [[ -f "settings" ]]; then
  # shellcheck disable=SC1091
  source "settings"
fi

: "${IRODS_PATH:?Missing IRODS_PATH (set in settings or environment)}"
: "${DAVRODS_SERVER:?Missing DAVRODS_SERVER (set in settings or environment)}"
: "${IRODS_TOKEN:?Missing IRODS_TOKEN (set in settings or environment)}"
: "${datasets:?Missing datasets (set in settings or environment)}"

IMAGE="${IMAGE:-ghcr.io/bihealth/seapiper:0.6.6}"
HOST_PORT="${HOST_PORT:-8080}"
TITLE="${TITLE:-SeaPiper}"

docker run --rm \
  -p "${HOST_PORT}:8080" \
  -e "IRODS_PATH=${IRODS_PATH}" \
  -e "DAVRODS_SERVER=${DAVRODS_SERVER}" \
  -e "IRODS_TOKEN=${IRODS_TOKEN}" \
  -e "TITLE=${TITLE}" \
  -e "datasets=${datasets}" \
  "${IMAGE}"
