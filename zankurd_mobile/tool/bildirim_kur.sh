#!/bin/bash
# Otomatik bildirim gönderimini (V2 sözleşmesi) kurar/yeniler.
#
# GPT-6 Pro ALAN 4: betik eskiden güncel, yalnız V2 RPC'lerini kullanan Edge'i
# dağıttıktan sonra eski `2026-10-13_push_delivery.sql` (V1) göçünü uyguluyordu:
# yeni ortamda V2 sözleşmesini kurmuyor, mevcut V2 ortamında ise pasifleştirilmiş
# V1 cron'unu yeniden etkinleştiriyordu. Son kontrol de yalnız "claimed"
# alanını aradığından kapalı V2 kapısından gelen sıfır iş yanıtını çalışan
# teslimat sayıyordu. Artık: V1 göçü UYGULANMAZ; V2 nesneleri Edge'den ÖNCE
# doğrulanır (yoksa dur: göçler `supabase/applied.md` sırasıyla uygulanır:
# 2026-10-31_push_delivery_v2.sql, ardından 2026-11-01_push_delivery_v2_closed_cutover.sql);
# V1 cron'un pasifliği denetlenir; sıfır iş yanıtı teslimat kanıtı SAYILMAZ.
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

# Edge dağıtımından ÖNCE: V2 sözleşmesi canlıda var mı, V1 cron pasif mi?
ONKOSUL="$(supabase db query --linked "select
  to_regprocedure('public.claim_push_outbox_v2(integer)') is not null
  and to_regprocedure('public.finish_push_outbox(uuid,uuid,text,text,integer)') is not null
  and to_regclass('public.push_delivery_v2_config') is not null as v2_var,
  not exists (select 1 from cron.job where jobname = 'send-push' and active) as v1_pasif,
  exists (select 1 from cron.job where jobname = 'send-push-v2' and active) as v2_cron;" 2>&1 || true)"
echo "$ONKOSUL" | grep -q 'true' || { echo "HATA: V2 nesneleri doğrulanamadı; önce V2 göçlerini uygula (bkz. supabase/applied.md)." >&2; exit 1; }
if echo "$ONKOSUL" | grep -q 'false'; then
  echo "HATA: V2 sözleşmesi eksik ya da V1 cron etkin / V2 cron yok. Çıktı:" >&2
  echo "$ONKOSUL" >&2
  exit 1
fi
echo "✓ V2 sözleşmesi var, V1 cron pasif, V2 cron etkin"
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

# Vault sırları yazıldı; göç UYGULANMAZ (V2 göçleri ayrı, sürüm denetimli).
YANIT="$(curl -s -X POST "$URL" -H "x-cron-secret: ${CRON}" -H "content-type: application/json" -d '{}')"
echo "Deneme çağrısı: $YANIT"
# Yanıt geçerli bir sayaç nesnesi olmalı ve hata/uyumsuzluk taşımamalı.
python3 - "$YANIT" <<'PY'
import json, sys
try:
    r = json.loads(sys.argv[1])
except ValueError:
    sys.exit("HATA: fonksiyon JSON dönmedi.")
if "error" in r or "claimed" not in r:
    sys.exit(f"HATA: fonksiyon beklenen sayaçları vermedi: {r.get('error', 'claimed yok')}")
if r.get("unsettled", 0) > 0:
    sys.exit("HATA: onaylanmayan iş var (unsettled).")
if r.get("claimed", 0) == 0:
    print("UYARI: claimed=0 TESLİMAT KANITI DEĞİLDİR (kuyruk boş ya da V2 kapısı kapalı).")
    print("       Gerçek cihaza bir bildirim gönderip claimed_at/sent sonucunu doğrula.")
PY
echo "✓ send-push yanıt verdi (kurulum tamam; teslimat kanıtı için gerçek cihaz denemesi gerekir)"
