#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

RUN_VISUAL=false
RUN_NATIVE=false
for arg in "$@"; do
  case "$arg" in
    --visual) RUN_VISUAL=true ;;
    --native) RUN_NATIVE=true ;;
    *)
      echo "Unknown argument: $arg" >&2
      echo "Usage: ./tool/design_qa.sh [--visual] [--native]" >&2
      exit 2
      ;;
  esac
done

echo "[Design QA] Static analysis"
dart analyze

echo "[Design QA] Static tap-target scan"
python3 tool/a11y/tap_target_taramasi.py

echo "[Design QA] Full Flutter test suite"
flutter test

if [[ "$RUN_VISUAL" == true ]]; then
  TOUR_DIR="${ZANKURD_SCREEN_TOUR_OUT_DIR:-.tmp/design_qa/tour}"
  echo "[Design QA] Screen tour -> $TOUR_DIR"
  ZANKURD_SCREEN_TOUR_OUT_DIR="$TOUR_DIR" \
    flutter test tool/screenshots/screen_tour_test.dart
fi

if [[ "$RUN_NATIVE" == true ]]; then
  PATROL_BIN="${PATROL_BIN:-$HOME/.pub-cache/bin/patrol}"
  if [[ ! -x "$PATROL_BIN" ]]; then
    PATROL_BIN="$(command -v patrol || true)"
  fi
  if [[ -z "$PATROL_BIN" || ! -x "$PATROL_BIN" ]]; then
    echo "[Design QA] Patrol CLI bulunamadı. dart pub global activate patrol_cli 4.8.0" >&2
    exit 1
  fi

  DEVICE="${ZANKURD_PATROL_DEVICE:-}"
  if [[ -z "$DEVICE" ]] && command -v xcrun >/dev/null 2>&1; then
    DEVICE="$(xcrun simctl list devices booted | awk '/iPhone/ && /Booted/ { id=$(NF-1); gsub(/[()]/, "", id); print id; exit }')"
  fi
  if [[ -z "$DEVICE" ]]; then
    echo "[Design QA] Boot edilmiş iOS Simulator yok. ZANKURD_PATROL_DEVICE ayarlanabilir." >&2
    exit 1
  fi

  echo "[Design QA] patrol test -> $DEVICE"
  "$PATROL_BIN" test -t patrol_test/smoke_test.dart -d "$DEVICE"

  echo "[Design QA] Native visual proof -> $DEVICE"
  ZANKURD_NATIVE_VISUAL_DEVICE="$DEVICE" ./tool/native_visual_qa.sh
fi

echo "[Design QA] PASS"
