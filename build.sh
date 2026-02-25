#!/usr/bin/env bash
set -euo pipefail

IMAGE="${IMAGE:-ghcr.io/bihealth/seapiper}"
TAG="${TAG:-0.6.1}"
BIOC_PKGS="${BIOC_PKGS:-DESeq2}"
# tmod currently tracks master upstream.
TMOD_REF="${TMOD_REF:-d583238f3559482b02cf34b9304a19b090006aca}"
RSEASNAP_REF="${RSEASNAP_REF:-66f4f705dbee586a5de197322a401652c43d0598}"
BIOSHMODS_REF="${BIOSHMODS_REF:-605712e12e7a1ab4baa49943025369a2d4539072}"
SEAPIPER_REF="${SEAPIPER_REF:-aab216da87e4203e5c6fea1f8a9534c8e00d266b}"
GGHALVES_REF="${GGHALVES_REF:-e5c3c79e79f13a00795a2a7774794252d1980d86}"
VCTRS_VERSION="${VCTRS_VERSION:-0.6.5}"

docker buildx build \
  --load \
  --build-arg VERSION="$TAG" \
  --build-arg BIOC_PKGS="$BIOC_PKGS" \
  --build-arg TMOD_REF="$TMOD_REF" \
  --build-arg RSEASNAP_REF="$RSEASNAP_REF" \
  --build-arg BIOSHMODS_REF="$BIOSHMODS_REF" \
  --build-arg SEAPIPER_REF="$SEAPIPER_REF" \
  --build-arg GGHALVES_REF="$GGHALVES_REF" \
  --build-arg VCTRS_VERSION="$VCTRS_VERSION" \
  -t "$IMAGE:$TAG" \
  build
