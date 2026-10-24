#!/usr/bin/env bash
# App의 ViewModel/설정 코드를 Linux에서 컴파일·테스트 (SwiftUI 뷰는 macOS CI에서 빌드 검증).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
IMAGE="${SWIFT_IMAGE:-swift:6.2-noble}"
if command -v swift >/dev/null 2>&1 && [[ "${USE_DOCKER:-0}" != "1" ]]; then
  cd "$ROOT/Tools/AppLogicHarness" && swift test "$@"
else
  docker run --rm -v "$ROOT:/work" -v garden-harness-cache:/work/Tools/AppLogicHarness/.build \
    -w /work/Tools/AppLogicHarness "$IMAGE" swift test "$@"
fi
