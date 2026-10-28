#!/bin/bash
# Mağaza paketini (ios: imzasız arşiv + IPA öncesi, android: AAB) yalnız
# üretim yapılandırmasıyla üretir ve çıkan ikilide RevenueCat anahtarının
# gerçekten bulunduğunu, değeri yazdırmadan doğrular.
#
# Niçin: `--dart-define-from-file` unutulunca derleme başarılı görünür, imza ve
# yükleme de geçer; uygulama ise açılışta "yapılandırma eksik" ekranında kalır.
# 2026-08-02'de AAB'de, 2026-10-13'te TestFlight build 23'te bu yaşandı.
#
# Kullanım: tool/surum_paketi.sh ios|android
set -euo pipefail
cd "$(dirname "$0")/.."

HEDEF="${1:-}"
ENV_FILE=".env.mobile.release.json"
[[ "$HEDEF" == ios || "$HEDEF" == android ]] || {
  echo "Kullanım: $0 ios|android" >&2
  exit 2
}
[[ -f "$ENV_FILE" ]] || { echo "HATA: $ENV_FILE yok." >&2; exit 1; }

dart run tool/validate_release_config.dart --file="$ENV_FILE" \
  --target=mobile --environment=production

anahtar_adi=REVENUECAT_API_KEY_IOS
[[ "$HEDEF" == android ]] && anahtar_adi=REVENUECAT_API_KEY_ANDROID
iz="$(python3 -c "import json,sys;print(json.load(open('$ENV_FILE'))['$anahtar_adi'][:16])")"

if [[ "$HEDEF" == ios ]]; then
  # İmzalı arşiv şart (2026-10-28): --no-codesign arşivinde yetki (entitlement)
  # gömülmez; dışa aktarma da eklemez. Build 39-40 IPA'sında aps-environment,
  # Apple ile giriş ve associated-domains YOKTU (codesign -d ile görüldü).
  flutter build ipa --release --dart-define-from-file="$ENV_FILE" \
    --export-options-plist=ios/ExportOptions.AppStore.plist
  ikili="build/ios/archive/Runner.xcarchive/Products/Applications/Runner.app/Frameworks/App.framework/App"
  LC_ALL=C grep -a -q -- "$iz" "$ikili" || {
    echo "HATA: arşivdeki ikilide iOS RevenueCat anahtarı yok; yükleme." >&2
    exit 1
  }
  # Crashlytics sembolleri: Xcode projesinde yükleme adımı yok; 2.1.0'a dek
  # hiçbir dSYM Firebase'e gitmemişti ve iOS çökmeleri "işlenmemiş" kalıyordu
  # (2026-10-23). Yükleme başarısızsa paket yine geçerlidir; yalnız uyarılır.
  semboller="build/ios/SourcePackages/checkouts/firebase-ios-sdk/Crashlytics/upload-symbols"
  if [[ -x "$semboller" ]]; then
    "$semboller" -gsp ios/Runner/GoogleService-Info.plist -p ios \
      build/ios/archive/Runner.xcarchive/dSYMs > /dev/null 2>&1 &&
      echo "✓ Crashlytics sembolleri yüklendi." ||
      echo "UYARI: Crashlytics sembolleri yüklenemedi; elle: $semboller -gsp ios/Runner/GoogleService-Info.plist -p ios build/ios/archive/Runner.xcarchive/dSYMs" >&2
  else
    echo "UYARI: $semboller yok; Crashlytics sembolleri yüklenmedi." >&2
  fi
else
  # --no-pub kullanma: Flutter release kayıtlarını yeniden üretmez ve
  # integration_test/patrol gibi geliştirme eklentileri Java derlemesini bozabilir.
  flutter build appbundle --release --dart-define-from-file="$ENV_FILE"
  aab="build/app/outputs/bundle/release/app-release.aab"
  gecici="$(mktemp -d)"
  trap 'rm -rf "$gecici"' EXIT
  unzip -q -o "$aab" 'base/lib/arm64-v8a/libapp.so' -d "$gecici"
  LC_ALL=C grep -a -q -- "$iz" "$gecici/base/lib/arm64-v8a/libapp.so" || {
    echo "HATA: AAB'deki ikilide Android RevenueCat anahtarı yok; yükleme." >&2
    exit 1
  }
fi
echo "✓ $HEDEF paketi üretim yapılandırmasıyla derlendi (anahtar ikilide var)."
