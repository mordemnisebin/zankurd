#!/bin/bash
# ZanKurd web çıktısını özel SSH anahtarı ve sabitlenmiş host key ile aktarır.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env.deploy"
DRY_RUN=false

if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=true
  shift
fi
if [[ "$#" -ne 0 ]]; then
  echo "HATA: Kullanım: $0 [--dry-run]" >&2
  exit 2
fi
if [[ ! -f "$ENV_FILE" ]]; then
  echo "HATA: $ENV_FILE bulunamadı." >&2
  echo "  cp .env.deploy.example .env.deploy" >&2
  exit 1
fi

SFTP_HOST=""
SFTP_USER=""
SFTP_PATH=""
SFTP_EXPECTED_REALPATH=""
SFTP_BACKUP_PATH=""
SFTP_PORT="22"
SFTP_IDENTITY_FILE=""
SFTP_KNOWN_HOSTS_FILE=""
LIVE_SITE_URL=""
LOCAL_DIR=""

load_config() {
  local line key value first last
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%$'\r'}"
    [[ -z "$line" || "$line" == \#* ]] && continue
    key="${line%%=*}"
    value="${line#*=}"
    if [[ "$key" == "$line" ]]; then
      echo "HATA: Geçersiz yapılandırma satırı: $key" >&2
      exit 1
    fi
    case "$key" in
      SFTP_HOST|SFTP_USER|SFTP_PATH|SFTP_EXPECTED_REALPATH|SFTP_BACKUP_PATH|SFTP_PORT|SFTP_IDENTITY_FILE|SFTP_KNOWN_HOSTS_FILE|LIVE_SITE_URL|LOCAL_DIR) ;;
      *)
        echo "HATA: Bilinmeyen yapılandırma anahtarı: $key" >&2
        exit 1
        ;;
    esac
    first="${value:0:1}"
    last="${value: -1}"
    if [[ ${#value} -ge 2 && "$first" == '"' && "$last" == '"' ]]; then
      value="${value:1:${#value}-2}"
    elif [[ ${#value} -ge 2 && "$first" == "'" && "$last" == "'" ]]; then
      value="${value:1:${#value}-2}"
    fi
    printf -v "$key" '%s' "$value"
  done < "$ENV_FILE"
}

safe_absolute_path() {
  local value="$1"
  [[ "$value" =~ ^/[A-Za-z0-9._/-]+$ ]] \
    && [[ "$value" != *".."* ]] \
    && [[ "$value" != *"//"* ]] \
    && [[ "$value" != "/" ]]
}

load_config

: "${SFTP_HOST:?SFTP_HOST tanımlı değil}"
: "${SFTP_USER:?SFTP_USER tanımlı değil}"
: "${SFTP_PATH:?SFTP_PATH tanımlı değil}"
: "${SFTP_EXPECTED_REALPATH:?SFTP_EXPECTED_REALPATH tanımlı değil}"
: "${SFTP_BACKUP_PATH:?SFTP_BACKUP_PATH tanımlı değil}"
: "${SFTP_IDENTITY_FILE:?SFTP_IDENTITY_FILE tanımlı değil}"
: "${SFTP_KNOWN_HOSTS_FILE:?SFTP_KNOWN_HOSTS_FILE tanımlı değil}"
: "${LIVE_SITE_URL:?LIVE_SITE_URL tanımlı değil}"

LOCAL_DIR="${LOCAL_DIR:-$SCRIPT_DIR/build/web}"
[[ "$LOCAL_DIR" == /* ]] || LOCAL_DIR="$SCRIPT_DIR/$LOCAL_DIR"

[[ "$SFTP_PORT" =~ ^[0-9]{1,5}$ ]] \
  && (( SFTP_PORT >= 1 && SFTP_PORT <= 65535 )) || {
    echo "HATA: SFTP_PORT 1–65535 arasında olmalı." >&2
    exit 1
  }
[[ "$SFTP_HOST" =~ ^[A-Za-z0-9.-]+$ ]] || {
  echo "HATA: SFTP_HOST geçersiz." >&2
  exit 1
}
[[ "$SFTP_USER" =~ ^[A-Za-z0-9._-]+$ ]] || {
  echo "HATA: SFTP_USER geçersiz." >&2
  exit 1
}
for remote_path in "$SFTP_PATH" "$SFTP_EXPECTED_REALPATH" "$SFTP_BACKUP_PATH"; do
  safe_absolute_path "$remote_path" || {
    echo "HATA: Güvenli olmayan uzak yol: $remote_path" >&2
    exit 1
  }
done
[[ "$SFTP_BACKUP_PATH/" != "$SFTP_PATH/"* ]] || {
  echo "HATA: Yedek dizini web kökünün dışında olmalı." >&2
  exit 1
}
safe_absolute_path "$SFTP_IDENTITY_FILE" || {
  echo "HATA: SSH anahtar yolu güvenli değil." >&2
  exit 1
}
safe_absolute_path "$SFTP_KNOWN_HOSTS_FILE" || {
  echo "HATA: known_hosts yolu güvenli değil." >&2
  exit 1
}
[[ "$LIVE_SITE_URL" =~ ^https://[A-Za-z0-9.-]+/?$ ]] || {
  echo "HATA: LIVE_SITE_URL geçerli bir HTTPS kökü olmalı." >&2
  exit 1
}
[[ -f "$SFTP_IDENTITY_FILE" ]] || {
  echo "HATA: Özel SSH anahtarı bulunamadı." >&2
  exit 1
}
[[ -s "$SFTP_KNOWN_HOSTS_FILE" ]] || {
  echo "HATA: Sabitlenmiş known_hosts dosyası bulunamadı." >&2
  exit 1
}
command -v ssh >/dev/null || {
  echo "HATA: ssh kurulu değil." >&2
  exit 1
}
command -v rsync >/dev/null || {
  echo "HATA: rsync kurulu değil." >&2
  exit 1
}

for output in index.html main.dart.js flutter_bootstrap.js .htaccess privacy.html terms.html delete-account.html; do
  [[ -f "$LOCAL_DIR/$output" ]] || {
    echo "HATA: Eksik web çıktısı: $LOCAL_DIR/$output" >&2
    exit 1
  }
done

SSH_OPTIONS=(
  -p "$SFTP_PORT"
  -i "$SFTP_IDENTITY_FILE"
  -o BatchMode=yes
  -o IdentitiesOnly=yes
  -o ConnectTimeout=15
  -o StrictHostKeyChecking=yes
  -o "UserKnownHostsFile=$SFTP_KNOWN_HOSTS_FILE"
)
REMOTE="$SFTP_USER@$SFTP_HOST"

ssh "${SSH_OPTIONS[@]}" "$REMOTE" \
  "command -v rsync >/dev/null && test -d '$SFTP_PATH' && test -w '$SFTP_PATH'" || {
    echo "HATA: Uzak rsync veya yazılabilir web kökü doğrulanamadı." >&2
    exit 1
  }
REMOTE_REALPATH="$(
  ssh "${SSH_OPTIONS[@]}" "$REMOTE" "cd '$SFTP_PATH' && pwd -P"
)"
if [[ "$REMOTE_REALPATH" != "$SFTP_EXPECTED_REALPATH" ]]; then
  echo "HATA: Uzak hedef beklenen gerçek yol değil." >&2
  echo "Beklenen: $SFTP_EXPECTED_REALPATH" >&2
  echo "Bulunan:  $REMOTE_REALPATH" >&2
  exit 1
fi

RSYNC_SSH="ssh -p $SFTP_PORT -i $SFTP_IDENTITY_FILE -o BatchMode=yes -o IdentitiesOnly=yes -o ConnectTimeout=15 -o StrictHostKeyChecking=yes -o UserKnownHostsFile=$SFTP_KNOWN_HOSTS_FILE"
RSYNC_OPTIONS=(
  -az
  --checksum
  --delay-updates
  --itemize-changes
  --exclude=.DS_Store
  --exclude=.last_build_id
)

if [[ "$DRY_RUN" == true ]]; then
  RSYNC_OPTIONS+=(--dry-run)
  echo "Güvenli aktarım ön izlemesi:"
else
  BACKUP_RUN="$SFTP_BACKUP_PATH/$(date -u +%Y%m%dT%H%M%SZ)"
  ssh "${SSH_OPTIONS[@]}" "$REMOTE" "mkdir -p '$BACKUP_RUN'"
  RSYNC_OPTIONS+=(--backup "--backup-dir=$BACKUP_RUN")
  echo "Şifreli web aktarımı başlıyor; değişen eski dosyalar: $BACKUP_RUN"
fi

rsync "${RSYNC_OPTIONS[@]}" \
  -e "$RSYNC_SSH" \
  "$LOCAL_DIR/" \
  "$REMOTE:$SFTP_PATH/"

if [[ "$DRY_RUN" == true ]]; then
  echo "Ön izleme tamamlandı; uzak dosyalar değiştirilmedi."
else
  echo "Aktarım tamamlandı."
fi
