#!/bin/bash
# Geriye dönük giriş noktası. Aktarım her zaman şifreli SSH üzerinden yapılır.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/deploy_sftp.sh" "$@"
