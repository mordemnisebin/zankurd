#!/bin/bash
# Mağaza yüklemesini tek komuta indirir: önce üretim paketini üretir ve
# doğrular (tool/surum_paketi.sh), sonra iOS için IPA'yı dışa aktarıp App Store
# Connect'e, Android için AAB'yi Play Console'a TASLAK olarak yükler.
#
# Niçin: 2026-10-13'te TestFlight build 23 üretim yapılandırması olmadan çıktı
# (bayrak unutulmuştu) ve aynı gün 157 MB'lık AAB tarayıcı otomasyonuyla elle
# yüklendi. Adımlar betikte olunca ne yüklendiği ve nasıl üretildiği değişmez.
#
# Kullanım: tool/yayinla.sh ios|android [--kuru]
#   --kuru   ağa yükleme dışında her şeyi yapar; yükleme komutunu gizli
#            değerler maskelenmiş olarak yazdırır.
#
# Ortam değişkenleri (depoda tutulmaz):
#   ios:     ASC_KEY_ID, ASC_ISSUER_ID  (.p8 anahtarını altool kendisi bulur)
#   android: PLAY_JSON_KEY              (Play servis hesabı JSON anahtarının yolu)
set -euo pipefail
cd "$(dirname "$0")/.."

HEDEF=""
KURU=0
for arg in "$@"; do
  case "$arg" in
    ios | android) HEDEF="$arg" ;;
    --kuru) KURU=1 ;;
    *)
      echo "Kullanım: $0 ios|android [--kuru]" >&2
      exit 2
      ;;
  esac
done
[[ -n "$HEDEF" ]] || {
  echo "Kullanım: $0 ios|android [--kuru]" >&2
  exit 2
}

hata() {
  echo "HATA: $*" >&2
  exit 1
}

# Yüklenen derleme bir commit'e karşılık gelsin: izlenen kod değişmişse dur.
if [[ -n "$(git status --porcelain --untracked-files=no -- lib pubspec.yaml)" ]]; then
  git status --short --untracked-files=no -- lib pubspec.yaml >&2
  hata "lib/ ya da pubspec.yaml'da işlenmemiş değişiklik var; önce commit et."
fi
COMMIT="$(git rev-parse --short HEAD)"
SURUM="$(sed -n 's/^version:[[:space:]]*//p' pubspec.yaml | head -n1)"
echo "Yayın: $HEDEF  commit $COMMIT  sürüm $SURUM"

# Gizli değer ve dosya denetimleri, ~10 dakikalık derlemeden ÖNCE yapılır.
if [[ "$HEDEF" == ios ]]; then
  [[ -n "${ASC_KEY_ID:-}" ]] || hata "ASC_KEY_ID tanımlı değil (App Store Connect API anahtar kimliği)."
  [[ -n "${ASC_ISSUER_ID:-}" ]] || hata "ASC_ISSUER_ID tanımlı değil (App Store Connect issuer kimliği)."
  p8_var=0
  for d in "$HOME/.appstoreconnect/private_keys" ./private_keys "$HOME/private_keys" /private_keys; do
    [[ -f "$d/AuthKey_${ASC_KEY_ID}.p8" ]] && p8_var=1
  done
  [[ "$p8_var" == 1 ]] || hata "AuthKey_${ASC_KEY_ID}.p8 ~/.appstoreconnect/private_keys/ altında yok."
else
  [[ -n "${PLAY_JSON_KEY:-}" ]] || hata "PLAY_JSON_KEY tanımlı değil (Play servis hesabı JSON anahtarının yolu; docs/YAYIN_ADIMLARI.md)."
  [[ -f "$PLAY_JSON_KEY" ]] || hata "PLAY_JSON_KEY dosyası bulunamadı: $PLAY_JSON_KEY"
  command -v fastlane > /dev/null || hata "fastlane kurulu değil."
  # Kurulum bozuksa (ör. eksik gem) yüklemeyi 10 dk'lık derlemeden sonra öğrenme.
  if ! fastlane --version > /dev/null 2>&1; then
    if [[ "$KURU" == 1 ]]; then
      echo "UYARI: 'fastlane --version' çalışmıyor; gerçek yüklemeden önce kurulumu onar." >&2
    else
      hata "fastlane çalışmıyor ('fastlane --version' başarısız); kurulumu onar."
    fi
  fi
fi

# Her zaman önce üretim paketi: yapılandırma doğrulaması ve ikilide anahtar denetimi.
tool/surum_paketi.sh "$HEDEF" || hata "tool/surum_paketi.sh başarısız; yükleme yapılmadı."

if [[ "$HEDEF" == ios ]]; then
  # Eski bir IPA yanlış dosyanın yüklenmesine yol açmasın.
  rm -rf build/ios/ipa
  xcodebuild -exportArchive \
    -archivePath build/ios/archive/Runner.xcarchive \
    -exportPath build/ios/ipa \
    -exportOptionsPlist ios/ExportOptions.AppStore.plist
  ipalar=(build/ios/ipa/*.ipa)
  [[ ${#ipalar[@]} -eq 1 && -f "${ipalar[0]}" ]] || hata "build/ios/ipa altında tam bir .ipa bekleniyordu."
  komut=(xcrun altool --upload-app -f "${ipalar[0]}" -t ios --apiKey "$ASC_KEY_ID" --apiIssuer "$ASC_ISSUER_ID")
  gosterim="xcrun altool --upload-app -f ${ipalar[0]} -t ios --apiKey <ASC_KEY_ID> --apiIssuer <ASC_ISSUER_ID>"
else
  aab="build/app/outputs/bundle/release/app-release.aab"
  [[ -f "$aab" ]] || hata "$aab yok."
  # draft: son gönderim kararı Play Console'da bir insanda kalır.
  komut=(fastlane run upload_to_play_store
    package_name:com.zankurd.app track:alpha "aab:$aab" "json_key:$PLAY_JSON_KEY"
    release_status:draft skip_upload_metadata:true skip_upload_images:true
    skip_upload_screenshots:true skip_upload_changelogs:true)
  gosterim="fastlane run upload_to_play_store package_name:com.zankurd.app track:alpha aab:$aab json_key:<PLAY_JSON_KEY> release_status:draft skip_upload_metadata:true skip_upload_images:true skip_upload_screenshots:true skip_upload_changelogs:true"
fi

if [[ "$KURU" == 1 ]]; then
  echo "[kuru] Yükleme yapılmadı. Çalıştırılacak komut:"
  echo "  $gosterim"
  exit 0
fi

echo "Yükleniyor: $gosterim"
"${komut[@]}"
echo "✓ $HEDEF yüklendi (commit $COMMIT, sürüm $SURUM)."
if [[ "$HEDEF" == android ]]; then
  echo "Taslak Play Console > Kapalı test - Alpha altında; gözden geçirip oradan gönder."
else
  echo "İşleme bittiğinde App Store Connect > TestFlight'ta görünür."
fi
