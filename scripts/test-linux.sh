#!/usr/bin/env bash
# GardenCore를 Linux(Docker swift 이미지)에서 빌드·테스트한다. macOS에서는 `swift test`만 실행해도 된다.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
IMAGE="${SWIFT_IMAGE:-swift:6.2-noble}"
if command -v swift >/dev/null 2>&1 && [[ "${USE_DOCKER:-0}" != "1" ]]; then
  cd "$ROOT/Packages/GardenCore" && swift test "$@"
else
  docker run --rm -v "$ROOT:/work" -v garden-swiftpm-cache:/work/Packages/GardenCore/.build \
    -w /work/Packages/GardenCore "$IMAGE" swift test "$@"
fi
