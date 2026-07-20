#!/bin/bash
# Otomatik deploy script for Flutter web build to Hostinger
# Kullanım:
#   FTP_PASS=<şifre> ./deploy-to-hostinger.sh
#   ./deploy-to-hostinger.sh <şifre>
#   # ya da kök dizindeki .env.deploy (git takibi dışında) varsa otomatik okunur.

set -e

# .env.deploy fallback (git takibi dışında, yalnızca yerel cihazda tutulur).
# Sıra: env var > CLI arg > .env.deploy.
ENV_FILE="$(dirname "$0")/.env.deploy"
FTP_HOST_FROM_FILE=""
FTP_USER_FROM_FILE=""
FTP_PASS_FROM_FILE=""
REMOTE_DIR_FROM_FILE=""
if [ -z "${FTP_PASS:-}" ] && [ -z "${1:-}" ] && [ -f "$ENV_FILE" ]; then
  # Güvenli okuma: her satırı KEY=VALUE olarak yükler, # ile yorumları atlar.
  while IFS='=' read -r key value || [ -n "$key" ]; do
    case "$key" in
      ''|\#*) continue ;;
    esac
    case "$key" in
      FTP_HOST)   FTP_HOST_FROM_FILE="$value" ;;
      FTP_USER)   FTP_USER_FROM_FILE="$value" ;;
      FTP_PASS)   FTP_PASS_FROM_FILE="$value" ;;
      FTP_REMOTE) REMOTE_DIR_FROM_FILE="$value" ;;
    esac
  done < "$ENV_FILE"
fi

FTP_SERVER="${FTP_SERVER:-${FTP_HOST_FROM_FILE:-82.25.102.137}}"
FTP_USER="${FTP_USER:-${FTP_USER_FROM_FILE:-u622615894.zankurd.com}}"
FTP_PASS="${FTP_PASS:-${1:-${FTP_PASS_FROM_FILE:-}}}"
REMOTE_DIR="${REMOTE_DIR:-${REMOTE_DIR_FROM_FILE:-public_html}}"
LOCAL_BUILD="./zankurd_mobile/build/web"

if [ -z "$FTP_PASS" ]; then
    echo "Kullanım: FTP_PASS=<şifre> ./deploy-to-hostinger.sh"
    echo "  ya da:  ./deploy-to-hostinger.sh <şifre>"
    exit 1
fi

echo "=========================================="
echo "Flutter Web Deploy Script"
echo "=========================================="
echo "Sunucu: $FTP_SERVER"
echo "Kullanıcı: $FTP_USER"
echo "Hedef: $REMOTE_DIR"
echo "=========================================="

if [ ! -d "$LOCAL_BUILD" ]; then
    echo "❌ HATA: Build klasörü bulunamadı: $LOCAL_BUILD"
    echo "Lütfen önce 'flutter build web' çalıştırın."
    exit 1
fi

echo "📤 Dosyalar yükleniyor..."

# Yeni dosyaları yükle (sadece değişen dosyaları)
cd "$LOCAL_BUILD"
find . -type f | while read file; do
    remote_file=$(echo "$file" | sed 's|^\./||')
    echo "📤 Yükleme: $remote_file"
    # -z: sadece değişen dosyaları yükle
    curl -s -z "$file" -T "$file" "ftp://$FTP_USER:$FTP_PASS@$FTP_SERVER/$REMOTE_DIR/$remote_file" || echo "⚠️  Yükleme başarısız: $remote_file"
done

echo "✅ Yükleme tamamlandı!"

echo "✅ Deploy tamamlandı!"
echo "🌐 Site: http://$FTP_USER@$FTP_SERVER/$REMOTE_DIR"
