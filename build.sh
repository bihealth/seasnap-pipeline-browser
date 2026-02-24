#!/usr/bin/env bash
set -euo pipefail

IMAGE="${IMAGE:-ghcr.io/bihealth/seapiper}"
TAG="${TAG:-0.6.0}"
# tmod currently tracks master upstream.
TMOD_REF="${TMOD_REF:-d583238f3559482b02cf34b9304a19b090006aca}"
RSEASNAP_REF="${RSEASNAP_REF:-66f4f705dbee586a5de197322a401652c43d0598}"
BIOSHMODS_REF="${BIOSHMODS_REF:-59566df2f0604ec9bbe1eeb5d63803468f408ffc}"
SEAPIPER_REF="${SEAPIPER_REF:-8202a01121529ac4680e066a94f6e9c3a64db83d}"
GGHALVES_REF="${GGHALVES_REF:-e5c3c79e79f13a00795a2a7774794252d1980d86}"

docker build \
  --build-arg VERSION="$TAG" \
  --build-arg TMOD_REF="$TMOD_REF" \
  --build-arg RSEASNAP_REF="$RSEASNAP_REF" \
  --build-arg BIOSHMODS_REF="$BIOSHMODS_REF" \
  --build-arg SEAPIPER_REF="$SEAPIPER_REF" \
  --build-arg GGHALVES_REF="$GGHALVES_REF" \
  -t "$IMAGE:$TAG" \
  build
