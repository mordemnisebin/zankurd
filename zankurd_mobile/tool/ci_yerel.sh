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
# Tarama bulgu dosyasını her koşuda yeniden yazar. `git checkout` ile geri
# almak commit edilmemiş elle değişikliği de siliyordu; önceki hâli aynen
# geri konur.
sik_bulgu=docs/content_batches/sik_kalite_bulgulari.json
sik_yedek=$(mktemp)
cp "$sik_bulgu" "$sik_yedek"
sik_durum=0
python3 tool/content_authoring/sik_kalite_taramasi.py || sik_durum=$?
cp "$sik_yedek" "$sik_bulgu"
rm -f "$sik_yedek"
[ "$sik_durum" -eq 0 ] || exit "$sik_durum"

adim "dokunma hedefi taraması"
python3 tool/a11y/tap_target_taramasi.py

if [[ "${1:-}" == "--tam" ]]; then
  # CI'nin "Render screen tour" adımı: yalnız flutter test'e bakılıp push
  # edilince bu adım CI'yı kırdı (2026-10-12, 96. kare yol değişince son
  # slayda varmıyordu). Kareler geçici klasöre basılır, repoyu kirletmez.
  adim "ekran turu"
  ZANKURD_SCREEN_TOUR_OUT_DIR="$(mktemp -d)" \
    flutter test --no-pub -r failures-only tool/screenshots/screen_tour_test.dart
  adim "flutter test"
  flutter test --no-pub -r failures-only
  adim "cihazsız uygulama akışları"
  # integration_test yolu Flutter'ın cihaz seçimini tetikler. Aynı
  # TestWidgetsFlutterBinding akışlarını normal test koşucusunda aç.
  flutter test --no-pub tool/ci_app_flows_test.dart
fi

printf '\nCI yerel: bütün adımlar geçti.\n'
