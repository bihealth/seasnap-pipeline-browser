#!/usr/bin/env bash
set -euo pipefail

IMAGE="${IMAGE:-ghcr.io/bihealth/seapiper}"
TAG="${TAG:-0.6.4}"
BIOC_PKGS="${BIOC_PKGS:-DESeq2,ComplexHeatmap}"
# tmod currently tracks master upstream.
TMOD_REF="${TMOD_REF:-d583238f3559482b02cf34b9304a19b090006aca}"
RSEASNAP_REF="${RSEASNAP_REF:-66f4f705dbee586a5de197322a401652c43d0598}"
BIOSHMODS_REF="${BIOSHMODS_REF:-v0.1.3}"
SEAPIPER_REF="${SEAPIPER_REF:-v0.1.5}"

docker buildx build \
  --load \
  --build-arg IMAGE_NAME="$IMAGE" \
  --build-arg VERSION="$TAG" \
  --build-arg BIOC_PKGS="$BIOC_PKGS" \
  --build-arg TMOD_REF="$TMOD_REF" \
  --build-arg RSEASNAP_REF="$RSEASNAP_REF" \
  --build-arg BIOSHMODS_REF="$BIOSHMODS_REF" \
  --build-arg SEAPIPER_REF="$SEAPIPER_REF" \
  -t "$IMAGE:$TAG" \
  build
