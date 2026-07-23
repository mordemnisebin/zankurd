#!/bin/bash
# FTP Deploy Script — ZanKurd Web Build → public_html
HOST="82.25.102.137"
USER="u622615894.zankurd.com"
PASS="Amargi.564721"
LOCAL_DIR="/Users/kocer/Projects/zankurd/zankurd_mobile/build/web"
REMOTE_DIR="public_html"

echo "FTP deploy başlıyor..."

# Tüm dosyaları recursive yükle
find "$LOCAL_DIR" -type f | while IFS= read -r file; do
  relative="${file#$LOCAL_DIR/}"
  remote_path="$REMOTE_DIR/$relative"
  remote_dir=$(dirname "$remote_path")
  
  curl -s --ftp-create-dirs \
    -T "$file" \
    "ftp://$HOST/$remote_path" \
    --user "$USER:$PASS" \
    --ftp-pasv \
    -m 30 || echo "HATA: $relative yüklenemedi"
done

echo "Deploy tamamlandı!"
