#!/usr/bin/env bash
# CI'nin analyze-and-test işini yerelde, aynı sırayla koşturur.
#
# Niçin: 2026-09-30'da iki push art arda CI'da kırıldı — biri dart format,
# biri şık kalite taraması (aynı soru kökü iki kez). İkisi de yerelde
# koşturulmamış adımlardı; yalnız flutter test'e bakılmıştı. Bu betik
# .github/workflows/flutter_ci.yml'deki adımları tek yerde toplar; push'tan
# önce koşturulur.
#
# Kullanım (zankurd_mobile/ içinden):
#   tool/ci_yerel.sh          # hızlı kapılar (format, analiz, içerik, a11y)
#   tool/ci_yerel.sh --tam    # + tam test ve cihazsız akışlar
set -euo pipefail
cd "$(dirname "$0")/.."

adim() { printf '\n== %s\n' "$1"; }

adim "dart format"
dart format --output=none --set-exit-if-changed \
  $(find . -name '*.dart' \
    -not -path './build/*' \
    -not -path '*/.dart_tool/*' \
    -not -path './lib/src/data/offline_question_bank.dart') >/dev/null

adim "dart analyze"
dart analyze

adim "soru kalitesi kapısı"
dart run tool/question_quality/question_quality_audit.dart gate

adim "şık kalite taraması"
python3 tool/content_authoring/sik_kalite_taramasi.py
# Tarama bulgu dosyasını her koşuda yeniden yazar; temizken değişiklik bırakmasın.
git checkout -q -- docs/content_batches/sik_kalite_bulgulari.json 2>/dev/null || true

adim "dokunma hedefi taraması"
python3 tool/a11y/tap_target_taramasi.py

if [[ "${1:-}" == "--tam" ]]; then
  adim "flutter test"
  flutter test --no-pub -r failures-only
  adim "cihazsız uygulama akışları"
  flutter test --no-pub -d flutter-tester integration_test/app_flows_test.dart
fi

printf '\nCI yerel: bütün adımlar geçti.\n'
