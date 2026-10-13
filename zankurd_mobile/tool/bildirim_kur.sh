#!/bin/bash
# Otomatik bildirim gönderimini canlıya kurar (supabase/2026-10-13_push_delivery.sql).
#
# Niçin tek betik: adımlar (sır, fonksiyon, Vault, göç) birbirine bağlı ve
# yarıda kalırsa cron ya sessizce hiçbir şey yapmaz ya da 401 alır. Betik
# her adımı sırayla yapar ve sonunda fonksiyonu bir kez çağırıp doğrular.
#
# Kullanım: tool/bildirim_kur.sh /yol/firebase-servis-hesabi.json
# Anahtar: Firebase konsolu → Proje ayarları → Hizmet hesapları → Yeni özel
# anahtar oluştur. Dosyayı depo DIŞINDA tut; betik içeriğini yazdırmaz.
set -euo pipefail
cd "$(dirname "$0")/.."

ANAHTAR="${1:-}"
[[ -n "$ANAHTAR" && -f "$ANAHTAR" ]] || { echo "Kullanım: $0 /yol/firebase-servis-hesabi.json" >&2; exit 2; }

python3 - "$ANAHTAR" <<'PY'
import json, sys
k = json.load(open(sys.argv[1]))
eksik = [a for a in ("project_id", "client_email", "private_key", "token_uri") if not k.get(a)]
if k.get("type") != "service_account" or eksik:
    sys.exit(f"HATA: servis hesabı JSON'u değil ya da eksik alan: {eksik}")
app = json.load(open("android/app/google-services.json"))["project_info"]["project_id"]
if k["project_id"] != app:
    sys.exit(f"HATA: anahtar '{k['project_id']}' projesine ait, uygulama '{app}' projesini kullanıyor.")
print(f"✓ servis hesabı {k['project_id']} projesine ait")
PY

REF="$(cat supabase/.temp/project-ref)"
URL="https://${REF}.supabase.co/functions/v1/send-push"
CRON="$(openssl rand -hex 32)"

supabase secrets set --project-ref "$REF" FCM_SERVICE_ACCOUNT_JSON="$(cat "$ANAHTAR")" CRON_SECRET="$CRON" > /dev/null
echo "✓ sırlar kaydedildi"

supabase functions deploy send-push --project-ref "$REF" --no-verify-jwt > /dev/null
echo "✓ send-push yayında"

# Değerler yalnız onaltılık ve URL karakteri içerir; SQL'e güvenle gömülür.
supabase db query --linked "do \$\$ declare v uuid; begin
  select id into v from vault.secrets where name = 'cron_secret';
  if v is null then perform vault.create_secret('${CRON}', 'cron_secret');
  else perform vault.update_secret(v, '${CRON}'); end if;
  select id into v from vault.secrets where name = 'send_push_url';
  if v is null then perform vault.create_secret('${URL}', 'send_push_url');
  else perform vault.update_secret(v, '${URL}'); end if;
end \$\$;" > /dev/null
echo "✓ Vault sırları yazıldı"

supabase db query --linked -f supabase/2026-10-13_push_delivery.sql > /dev/null
echo "✓ göç uygulandı (cron her dakika)"

YANIT="$(curl -s -X POST "$URL" -H "x-cron-secret: ${CRON}" -H "content-type: application/json" -d '{}')"
echo "Deneme çağrısı: $YANIT"
[[ "$YANIT" == *'"claimed"'* ]] || { echo "HATA: fonksiyon beklenen yanıtı vermedi." >&2; exit 1; }
echo "✓ otomatik bildirim gönderimi çalışıyor"
