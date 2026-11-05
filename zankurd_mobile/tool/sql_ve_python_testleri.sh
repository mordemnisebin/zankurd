#!/usr/bin/env bash
# SQL'i gerçekten çalıştıran PGlite araçlarını ve Python unit testlerini koşar.
#
# Niçin: sekiz PGlite aracı ile beş dosyadaki 38 Python testi hiçbir kapıdan
# çağrılmıyordu (GPT-6 Pro alan 8 denetimi); Python tarayıcılarının kendisi
# çalışsa da kendi testlerini çalıştıran yoktu ve PGlite sürümü kilitli
# değildi. Bu betik hem .github/workflows/flutter_ci.yml'den hem
# tool/ci_yerel.sh --tam'dan çağrılır; biri başarısızsa betik durur.
#
# PGlite SÜRÜMÜ BURADA KİLİTLİDİR (PostgreSQL 17.5). Önbellek klasörü
# ZK_PGLITE_DIR ile değişir; ağ yalnız ilk kurulumda gerekir.
set -euo pipefail
cd "$(dirname "$0")/.."

PGLITE_SURUMU="0.3.14"
KLASOR="${ZK_PGLITE_DIR:-${HOME}/.cache/zankurd/pglite-${PGLITE_SURUMU}}"
MODUL="${KLASOR}/node_modules/@electric-sql/pglite/dist/index.js"

if [[ ! -f "$MODUL" ]]; then
  echo "PGlite ${PGLITE_SURUMU} kuruluyor: $KLASOR"
  mkdir -p "$KLASOR"
  npm install --no-audit --no-fund --silent --prefix "$KLASOR" \
    "@electric-sql/pglite@${PGLITE_SURUMU}"
fi
[[ -f "$MODUL" ]] || { echo "HATA: PGlite kurulamadı: $MODUL" >&2; exit 1; }

echo "== SQL araçları (PGlite ${PGLITE_SURUMU})"
for arac in \
  test_guvenlik_tur7_local test_olcek_tur3_local test_olcek_tur4_local \
  test_olcek_tur5_local test_olcek_tur6_local test_push_delivery_v2_local \
  test_room_duel_guards_local verified_quiz_sql_smoke \
  test_yonetim_paneli_local test_yonetim_moderasyon_local \
  test_rekabet_sunum_local test_rekabet_sunum_guard_local \
  test_w4_apple_hesap_silme_local test_w4_push_cihazlar_local \
  test_seri_dondurma_ust_sinir_local; do
  echo "-- $arac"
  # verified_quiz_sql_smoke yolu ortam değişkeninden, ötekiler argümandan okur.
  PGLITE_MODULE="$MODUL" node "tool/${arac}.mjs" "$MODUL"
done

echo "== Python unit testleri"
(cd tool && python3 -m unittest -q test_send_push_outbox test_prepare_room_limits test_push_delivery_v2_sql)
(cd tool/content_authoring && python3 -m unittest -q test_editorial_queue test_authoring_gates)
(cd tool/a11y && python3 -m unittest -q tap_target_taramasi_test)
echo "SQL araçları ve Python testleri geçti."
