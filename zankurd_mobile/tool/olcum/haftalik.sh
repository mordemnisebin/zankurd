#!/bin/bash
# Canlı Supabase'ten son 8 haftanın kullanım sayılarını ve son 28 günün
# mod bazlı tur tamamlama hunisini basar (salt okuma).
# Niçin: sunucudaki oda, düello, ders, oturum ve anonim analitik (quiz_start /
# quiz_complete) kayıtlarından tutunma ve yarıda bırakılan modlar okunur.
# Sınırlar: analitiği ayarlardan kapatan veya çevrimdışı tek kişilik oynayan
# kullanıcıda olay kaydı oluşmaz; geliştirici test hesapları ayıklanmaz.
# Son haftanın dönüş oranı henüz olgunlaşmadığı için boştur.
set -euo pipefail
cd "$(dirname "$0")/../.."
supabase db query --linked -f tool/olcum/haftalik.sql 2>/dev/null | python3 -c '
import json, sys
t = sys.stdin.read()
rows = json.loads(t[t.index("{"):])["rows"]
cols = ["hafta_basi","aktif","yeni","donen","donus_yuzde","oda","biten_oda","duello","biten_duello","biten_ders","tur_bas","tur_bit","tur_bitis_yuzde"]
head = ["hafta","aktif","yeni","dönen","dönüş%","oda","biten oda","düello","biten düello","biten ders","tur baş","tur bit","tur%"]
w = [max(len(h), *(len(str(r.get(c) if r.get(c) is not None else "-")) for r in rows)) for h, c in zip(head, cols)]
print("  ".join(h.rjust(x) for h, x in zip(head, w)))
for r in rows:
    print("  ".join(str(r.get(c) if r.get(c) is not None else "-").rjust(x) for c, x in zip(cols, w)))
'

if [ -f tool/olcum/mod_hunisi.sql ]; then
  echo ""
  echo "=== Son 28 Tamamlanmış Gün Mod Bazlı Tur Olay Özeti (bitiş/başlangıç olay oranı) ==="
  supabase db query --linked -f tool/olcum/mod_hunisi.sql 2>/dev/null | python3 -c '
import json, sys
t = sys.stdin.read()
if "{" not in t:
    sys.exit(0)
rows = json.loads(t[t.index("{"):]).get("rows", [])
if not rows:
    print("(kayıt yok)")
    sys.exit(0)
cols = ["mod","baslayan_tur","biten_tur","eslesen_tur","bitis_baslangic_yuzde","baslayan_kisi","bitiren_kisi"]
head = ["mod","başlangıç","bitiş","eşleşen tur","bitiş/baş%","başlayan kişi","bitiren kişi"]
w = [max(len(h), *(len(str(r.get(c) if r.get(c) is not None else "-")) for r in rows)) for h, c in zip(head, cols)]
print("  ".join(h.rjust(x) for h, x in zip(head, w)))
for r in rows:
    print("  ".join(str(r.get(c) if r.get(c) is not None else "-").rjust(x) for c, x in zip(cols, w)))
'
fi
