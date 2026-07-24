#!/bin/bash
# FTP Deploy Script — ZanKurd Web Build → public_html
#
# Gizli bilgiler (host/kullanıcı/şifre) KOD İÇİNE YAZILMAZ. Bunlar
# git tarafından yok sayılan `.env.deploy` dosyasından okunur (bkz.
# .gitignore). Örnek içerik için `.env.deploy.example` dosyasına bak.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env.deploy"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "HATA: $ENV_FILE bulunamadı." >&2
  echo "  cp .env.deploy.example .env.deploy   ve içini doldur." >&2
  exit 1
fi

# shellcheck disable=SC1090
source "$ENV_FILE"

: "${FTP_HOST:?FTP_HOST tanımlı değil (.env.deploy)}"
: "${FTP_USER:?FTP_USER tanımlı değil (.env.deploy)}"
: "${FTP_PASS:?FTP_PASS tanımlı değil (.env.deploy)}"

LOCAL_DIR="${LOCAL_DIR:-$SCRIPT_DIR/build/web}"
REMOTE_DIR="${REMOTE_DIR:-public_html}"

echo "FTP deploy başlıyor..."

# Tüm dosyaları recursive yükle
find "$LOCAL_DIR" -type f | while IFS= read -r file; do
  relative="${file#"$LOCAL_DIR"/}"
  remote_path="$REMOTE_DIR/$relative"

  curl -s --ftp-create-dirs \
    -T "$file" \
    "ftp://$FTP_HOST/$remote_path" \
    --user "$FTP_USER:$FTP_PASS" \
    --ftp-pasv \
    -m 30 || echo "HATA: $relative yüklenemedi"
done

echo "Deploy tamamlandı!"
