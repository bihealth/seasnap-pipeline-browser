#!/usr/bin/env bash
set -euo pipefail

IMAGE="${IMAGE:-ghcr.io/bihealth/seapiper}"
TAG="${TAG:-0.6.0}"

docker build \
  --build-arg VERSION="$TAG" \
  -t "$IMAGE:$TAG" \
  build
