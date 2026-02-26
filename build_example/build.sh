#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

IMAGE="${IMAGE:-ghcr.io/bihealth/seapiper-example}"
TAG="${TAG:-0.1.0}"

docker buildx build \
  --load \
  -t "${IMAGE}:${TAG}" \
  "${REPO_DIR}/build_example"
