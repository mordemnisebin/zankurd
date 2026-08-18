#!/bin/bash
# Analiz, test, release derleme, güvenli aktarım ve canlı doğrulama.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFINE_FILE="$SCRIPT_DIR/.env.web.release.json"
BUILD_DIR="$SCRIPT_DIR/build/web"

if [[ ! -f "$DEFINE_FILE" ]]; then
  echo "HATA: $DEFINE_FILE bulunamadı." >&2
  echo "  cp .env.web.release.example.json .env.web.release.json" >&2
  exit 1
fi

cd "$SCRIPT_DIR"
dart analyze
flutter test
dart run tool/validate_release_config.dart \
  --file="$DEFINE_FILE" --target=web --environment=production
# `--no-web-resources-cdn` olmadan Flutter, 7,2 MB'lık canvaskit.wasm'ı
# gstatic.com'dan çeker: gstatic'in engellendiği ağlarda site boş ekran
# verir ve ziyaretçinin IP'si Google'a gider. Bayrak 0c8ea27'de README'ye,
# kontrol listesine ve CI'ya yazıldı ama kontrol listesinin 1. maddesinin
# çalıştırmanı söylediği bu betiğe yazılmadı; kusur bir sonraki yayında
# geri gelecekti (2026-07-31 denetimi).
flutter build web --release --no-web-resources-cdn \
  --dart-define-from-file="$DEFINE_FILE"

# Bayrak sessizce düşerse dağıtım durmalı: derlenen bootstrap gerçekten
# yerel CanvasKit'i mi işaret ediyor, onu doğrula.
grep -Eq 'useLocalCanvasKit:!0|"useLocalCanvasKit":true|useLocalCanvasKit:true' \
  "$BUILD_DIR/flutter_bootstrap.js" || {
  echo "HATA: CanvasKit hâlâ CDN'den yükleniyor; --no-web-resources-cdn etkisiz." >&2
  exit 1
}

for legal in privacy.html terms.html delete-account.html; do
  cmp -s "$SCRIPT_DIR/web/$legal" "$BUILD_DIR/$legal" || {
    echo "HATA: Derlemedeki $legal güncel kaynakla eşleşmiyor." >&2
    exit 1
  }
done

"$SCRIPT_DIR/deploy_sftp.sh" --dry-run
"$SCRIPT_DIR/deploy_sftp.sh"

LIVE_SITE_URL="$(
  awk -F= '$1 == "LIVE_SITE_URL" {value=$2; gsub(/^"|"$/, "", value); print value}' \
    "$SCRIPT_DIR/.env.deploy"
)"
[[ "$LIVE_SITE_URL" =~ ^https://[A-Za-z0-9.-]+/?$ ]] || {
  echo "HATA: Canlı HTTPS adresi okunamadı." >&2
  exit 1
}
LIVE_SITE_URL="${LIVE_SITE_URL%/}"
VERIFY_DIR="$(mktemp -d)"
trap 'rm -rf "$VERIFY_DIR"' EXIT

verify_page() {
  local path="$1"
  local marker="$2"
  local output="$VERIFY_DIR/${path//\//_}.html"
  curl --fail --silent --show-error --location --max-time 25 \
    "$LIVE_SITE_URL/$path" --output "$output"
  grep -Fq "$marker" "$output" || {
    echo "HATA: Canlı sayfa beklenen içeriği taşımıyor: /$path" >&2
    exit 1
  }
}

verify_legal_page() {
  local path="$1"
  local output="$VERIFY_DIR/live-$path"
  curl --fail --silent --show-error --location --max-time 25 \
    "$LIVE_SITE_URL/$path" --output "$output"
  cmp -s "$SCRIPT_DIR/web/$path" "$output" || {
    echo "HATA: Canlı /$path kaynak dosyayla birebir eşleşmiyor." >&2
    exit 1
  }
}

verify_header() {
  local path="$1"
  local header="$2"
  local expected="$3"
  local slug="${path//\//_}"
  [[ -n "$slug" ]] || slug="root"
  local raw_headers="$VERIFY_DIR/$slug.headers.raw"
  local final_headers="$VERIFY_DIR/$slug.headers.final"

  curl --fail --silent --show-error --location --max-time 25 \
    --dump-header "$raw_headers" "$LIVE_SITE_URL/$path" --output /dev/null

  # Yönlendirme varsa yalnızca son HTTP yanıtının başlıklarını doğrula.
  awk '
    /^HTTP\// { block = "" }
    { block = block $0 ORS }
    END { printf "%s", block }
  ' "$raw_headers" > "$final_headers"

  if ! awk -F: -v name="$header" '
    tolower($1) == tolower(name) {
      sub(/^[^:]*:[[:space:]]*/, "")
      print
    }
  ' "$final_headers" | grep -Fiq -- "$expected"; then
    echo "HATA: Canlı /$path yanıtında $header başlığı beklenen değeri taşımıyor." >&2
    exit 1
  fi
}

verify_page "" "ZanKurd"
verify_legal_page "privacy.html"
verify_legal_page "terms.html"
verify_legal_page "delete-account.html"
verify_header "" "Content-Security-Policy" "default-src 'self'"
verify_header "" "X-Content-Type-Options" "nosniff"
verify_header "main.dart.js" "Cache-Control" "no-cache"
verify_header "main.dart.js" "Cache-Control" "must-revalidate"
echo "Canlı web yayını ve yasal sayfalar doğrulandı: $LIVE_SITE_URL"
