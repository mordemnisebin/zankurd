#!/bin/bash
# Canlı Supabase'ten son 8 haftanın kullanım sayılarını basar (salt okuma).
# Niçin: analitik varsayılan kapalı olduğundan uygulamanın tutunup tutunmadığı
# ancak sunucudaki oda, düello, ders ve oturum kayıtlarından okunabilir.
# Sınırlar: misafir oturum yenilemesi last_sign_in_at'i güncellemez, yalnız
# yalnız tek kişilik oynayan kullanıcı burada eksik sayılır; geliştirici test
# hesapları ayıklanmaz. Son haftanın dönüş oranı henüz olgunlaşmadığı için boştur.
set -euo pipefail
cd "$(dirname "$0")/../.."
supabase db query --linked -f tool/olcum/haftalik.sql 2>/dev/null | python3 -c '
import json, sys
t = sys.stdin.read()
rows = json.loads(t[t.index("{"):])["rows"]
cols = ["hafta_basi","aktif","yeni","donen","donus_yuzde","oda","biten_oda","duello","biten_duello","biten_ders"]
head = ["hafta","aktif","yeni","dönen","dönüş%","oda","biten oda","düello","biten düello","biten ders"]
w = [max(len(h), *(len(str(r[c] if r[c] is not None else "-")) for r in rows)) for h, c in zip(head, cols)]
print("  ".join(h.rjust(x) for h, x in zip(head, w)))
for r in rows:
    print("  ".join(str(r[c] if r[c] is not None else "-").rjust(x) for c, x in zip(cols, w)))
'
