#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

DEVICE="${ZANKURD_NATIVE_VISUAL_DEVICE:-${1:-}}"
if [[ -z "$DEVICE" ]]; then
  DEVICE="$(xcrun simctl list devices booted | awk '/iPhone/ && /Booted/ { id=$(NF-1); gsub(/[()]/, "", id); print id; exit }')"
fi
if [[ -z "$DEVICE" ]]; then
  echo "[Native Visual QA] Boot edilmiş iOS Simulator bulunamadı." >&2
  exit 1
fi

OUT_DIR="${ZANKURD_NATIVE_VISUAL_OUT_DIR:-.tmp/design_qa/native}"
mkdir -p "$OUT_DIR"

echo "[Native Visual QA] device=$DEVICE out=$OUT_DIR"
flutter test integration_test/native_visual_qa_test.dart -d "$DEVICE" 2>&1 |
  while IFS= read -r line; do
    echo "$line"
    if [[ "$line" =~ CAPTURE_SCREENSHOT:\ ([A-Za-z0-9_-]+) ]]; then
      name="${BASH_REMATCH[1]}"
      xcrun simctl io "$DEVICE" screenshot "$OUT_DIR/$name.png"
      echo "[Native Visual QA] captured $name"
    fi
  done

for required in native_leaderboard native_spin_wheel; do
  file="$OUT_DIR/$required.png"
  if [[ ! -s "$file" ]]; then
    echo "[Native Visual QA] Eksik kanıt: $file" >&2
    exit 1
  fi
done

echo "[Native Visual QA] PASS"
