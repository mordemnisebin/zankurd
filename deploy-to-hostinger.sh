#!/bin/bash
# Otomatik deploy script for Flutter web build to Hostinger
# Kullanım: ./deploy-to-hostinger.sh

set -e

FTP_SERVER="82.25.102.137"
FTP_USER="u622615894.zankurd.com"
# Şifre asla bu dosyaya yazılmaz: ortamdan ya da ilk argümandan alınır.
FTP_PASS="${FTP_PASS:-$1}"
REMOTE_DIR="public_html"
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
