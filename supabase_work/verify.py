import json, sys
sys.path.insert(0, '.')
from sb import query

print("== yeni toplam ==")
print(query("SELECT count(*) AS n FROM public.questions"))
print("== kategori bazinda (onayli) ==")
for r in query("SELECT c.name, count(q.id) AS n FROM public.categories c LEFT JOIN public.questions q ON q.category_id=c.id AND q.is_approved GROUP BY c.name ORDER BY c.name"):
    print(r)
print("== yeni dalga kaynaklari ==")
print(query("SELECT source_url, count(*) FROM public.questions WHERE source_url IN ('zankurd_offline_curated_2026_07_19','zankurd_zk_csv_duzeltilmis_2026_07_19') GROUP BY 1"))
print("== ornek yeni kayit ==")
print(query("SELECT prompt, correct_option, question_type FROM public.questions WHERE source_url='zankurd_zk_csv_duzeltilmis_2026_07_19' LIMIT 2"))
print("== ZK duzeltme kontrol ==")
for p, beklenen in [("Kürt toplumunda dini çeşitlilik için en doğru ifade hangisidir?", 'A'),
                    ("ZanKurd gibi bir öğrenme uygulamasında soru bankasının en faydalı biçimi hangisi", 'A'),
                    ("Kürtçe NLP çalışmalarının artması ZanKurd gibi uygulamalara nasıl katkı sağlar?", 'A')]:
    esc = p.replace("'", "''")
    print(query("SELECT correct_option FROM public.questions WHERE prompt LIKE '" + esc + "%'"))
# tekrar calistirilabilirlik: ayni NOT EXISTS ile kac satir daha eklenecekti
print("== idempotency: yeni dalga promptlari canlida ==")
print(query("SELECT count(*) FILTER (WHERE source_url='zankurd_offline_curated_2026_07_19') AS o, count(*) FILTER (WHERE source_url='zankurd_zk_csv_duzeltilmis_2026_07_19') AS c FROM public.questions"))
