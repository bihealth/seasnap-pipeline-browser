#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ -f "${SCRIPT_DIR}/settings" ]]; then
  # shellcheck disable=SC1091
  source "${SCRIPT_DIR}/settings"
fi

: "${IRODS_PATH:?Missing IRODS_PATH (set in build_example/settings or environment)}"
: "${DAVRODS_SERVER:?Missing DAVRODS_SERVER (set in build_example/settings or environment)}"
: "${IRODS_TOKEN:?Missing IRODS_TOKEN (set in build_example/settings or environment)}"
: "${IRODS_FILE:?Missing IRODS_FILE (set in build_example/settings or environment)}"

IMAGE="${IMAGE:-ghcr.io/bihealth/seapiper-example}"
TAG="${TAG:-0.1.0}"
HOST_PORT="${HOST_PORT:-8080}"
TITLE="${TITLE:-SODAR Shiny Blueprint}"

docker run --rm \
  -p "${HOST_PORT}:8080" \
  -e "IRODS_PATH=${IRODS_PATH}" \
  -e "DAVRODS_SERVER=${DAVRODS_SERVER}" \
  -e "IRODS_TOKEN=${IRODS_TOKEN}" \
  -e "IRODS_FILE=${IRODS_FILE}" \
  -e "TITLE=${TITLE}" \
  "${IMAGE}:${TAG}"
