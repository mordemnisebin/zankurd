#!/bin/bash
# Deployment script for Flutter web build to Hostinger
# Usage: ./deploy-to-hostinger.sh

FTP_SERVER="82.25.102.137"
FTP_USER="u622615894.zankurd.com"
FTP_PASS="$1"  # Pass password as argument or set below
REMOTE_DIR="public_html"
LOCAL_BUILD="./zankurd_mobile/build/web"

if [ -z "$FTP_PASS" ]; then
    echo "Usage: ./deploy-to-hostinger.sh <ftp_password>"
    echo "Or set FTP_PASS environment variable"
    exit 1
fi

if [ ! -d "$LOCAL_BUILD" ]; then
    echo "Error: Build directory not found at $LOCAL_BUILD"
    exit 1
fi

echo "Uploading Flutter web build to Hostinger..."
echo "Target: ftp://$FTP_USER@$FTP_SERVER/$REMOTE_DIR"

# Upload all files
cd "$LOCAL_BUILD"
find . -type f | while read file; do
    remote_file=$(echo "$file" | sed 's|^\./||')
    echo "Uploading: $remote_file"
    curl -T "$file" "ftp://$FTP_USER:$FTP_PASS@$FTP_SERVER/$REMOTE_DIR/$remote_file" || echo "Failed: $remote_file"
done

echo "Deployment complete!"
