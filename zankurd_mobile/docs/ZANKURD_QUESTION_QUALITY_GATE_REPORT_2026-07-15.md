# ZanKurd Soru Kalitesi Yayın Kapısı Raporu — 2026-07-15

## 1. Executive summary

Faz 0B, soru kaynaklarına dokunmadan 44 sınıflandırılmış kaynağı denetleyen deterministik bir auditor ve mevcut borcu kötüleşmeye karşı kilitleyen CI kapısı oluşturdu. Report kapsamı 102.460 fiziksel kayıt, 61.358 parse edilmiş kayıt ve 38.629 kanonik tekil kayıttır. Gate kapsamı 13.571 fiziksel/kanonik kayıttır. Bilinmeyen kaynak ve kayıp production kaynağı yoktur. Gate, kabul edilmiş baseline'a karşı exit 0 vermiştir; bu sonuç mevcut kalite borcunun giderildiği anlamına gelmez.

## 2. İncelenen branch ve commit

- Başlangıç: `codex/phase0a-release-gates-2026-07-15` / `f58eba40eb76dbdebd4e43dccc82001b595d2456`
- Denetim branch'i: `codex/phase0b-question-quality-gate-2026-07-15`
- Metriklerin alındığı uygulama commit'i: `1314b468e9b254ae4b59226b557ab8467ac5f4fd`

## 3. İncelenen soru kaynakları

Manifest 44 fiziksel eşleşmeyi yedi rolde sınıflandırdı. Tam yol, parser, beklenen/gerçek kayıt ve gate bayrakları `docs/audit/question_quality/2026-07-15/source_inventory.csv` içindedir. Roller: `runtime_primary`, `runtime_secondary`, `publish_candidate`, `import_candidate`, `historical_snapshot`, `candidate_pool`, `quarantine`.

## 4. Her kaynağın gerçek kayıt sayısı

| Kaynak/grup | Rol | Fiziksel | Parse edilen | Gate |
|---|---:|---:|---:|---:|
| `offline_question_bank.dart` | runtime_primary | 3.125 | 3.125 | evet |
| `curated_question_bank.dart` | runtime_secondary | 20 | 20 | evet |
| canlı Kurmancî export | runtime_secondary | 377 | 377 | evet |
| `questions_import_ready.csv` | import_candidate | 10.000 | 10.000 | evet |
| wave-2 publish candidates | publish_candidate | 49 | 49 | evet |
| candidate pool dosyaları | candidate_pool | 17.551 | 17.551 | hayır |
| tarihsel CSV/SQL snapshot'ları | historical_snapshot | 61.387 | 20.285 | hayır |
| wave-2 quarantine | quarantine | 9.951 | 9.951 | hayır |
| **Toplam** |  | **102.460** | **61.358** | **13.571** |

SQL girdileri `sql_count` parser'ı ile yalnız fiziksel kayıt sayısına katılır; içerikleri kanonik/editoryal kontrollere dahil değildir. Globa açılan manifest pattern'lerinin 44 satırlık ayrıntısı kaynak envanteri CSV'sindedir.

## 5. Runtime'da kullanılan kaynaklar

Runtime rolündeki kaynaklar toplam 3.522 kayıttır: 3.125 primary, 397 secondary. Gate ayrıca 10.000 aktif import ve 49 publish adayı içerir. Gate'in 13.571 kaydının %25,95'i runtime, %73,69'u aktif import, %0,36'sı publish adayıdır.

## 6. Yapısal blocker'lar

Report kapsamındaki 59.901 BLOCKER satırı birbirini dışlamayan issue sayısıdır. Bunların içinde 22.538 duplicate option ve 31 invalid correct-answer vardır. Gate baseline'ında 3.501 BLOCKER bulunur. Eşik: boş soru, ikiden az seçenek, parse kaybı veya geçersiz doğru cevap BLOCKER. Güven: yapısal kontrollerde yüksek; aynı kayıt birden fazla kontrolü tetikleyebildiği için sayı tekil soru sayısı değildir.

## 7. Critical ihlaller

Report kapsamı 49.988, gate kapsamı 4.968 CRITICAL issue içerir. Başlıca kümeler: 36.246 exact-duplicate excess satırı, 5.530 yüksek güvenli Türkçe template ve 8.150 zaman-duyarlı bilgi adayı; 62 answer leak ayrıca critical'dır. Heuristik dil/dinamik kontrollerde güven orta-yüksek ve false positive olasılığı vardır.

## 8. Exact duplicate özeti

36.246 fazla duplicate satırı ve stabil issue fingerprint'e göre 24.412 grup saptandı. Payda 61.358 parse edilmiş kayıttır; fazla satır oranı %59,07'dir. Eşik normalize soru/seçenek kimliği eşitliğidir. Güven yüksek; aynı gerçek sorunun bilinçli snapshot kopyaları report borcunu yükseltebilir.

## 9. Near duplicate özeti

19.413 tekilleştirilmiş aday, 61.358 kayıt içinde %31,64 oranındadır. Eşik token-bucket sonrası Jaccard benzerliğidir. Bunlar kesin duplicate değildir; güven aday bazında orta ve false positive olasılığı özellikle kısa/şablon sorularda yüksektir.

## 10. Türkçe/Kurmancî karışımı

5.530 yüksek güvenli Türkçe template adayı (%9,01) vardır. Eşik bilinen Türkçe kalıp listesi ve normalize metin eşleşmesidir. Bu araç Kurmancî gramer doğruluğunu kanıtlamaz; false positive ve kaçırma mümkündür, sonuçlar dil uzmanı incelemesi gerektirir.

## 11. Doğru seçenek dağılımı

61.358 kayıtta A 28.309 (%46,14), B 18.288 (%29,81), C 7.868 (%12,82), D 6.893 (%11,23). Global A-D farkı 34,91 puandır ve belirgin bias adayıdır. Bu sürüm global dağılım üretir; kaynak/kategori/alt kategori/zorluk kırılımlarını tam uygulamaz. Güven global sayımda yüksek, pedagojik yorumda orta.

## 12. Answer leak analizi

62 aday / 61.358 kayıt = %0,10. Eşik, en az anlamlı uzunluktaki doğru cevabın normalize soru içinde görünmesidir; kısa yanıtlar dışlanır. Güven yüksek-orta, çekimli biçimler ve doğal bağlam false positive üretebilir.

## 13. Açıklama kalite adayları

7.332 kısa açıklama adayı (%11,95) saptandı. Ayrıca yalnız cevabı tekrar eden açıklama ve generated kalıntı kontrolleri çalışır; mevcut gerçek veride ayrı check toplamı sıfırdır. Eşik sekiz karakterden kısa açıklamadır. Güven uzunlukta yüksek, kalite yorumunda düşüktür.

## 14. Güncel bilgi riski

8.150 aday / 61.358 = %13,28. `bugün`, `şu an`, başkan, seçim, nüfus ve eşdeğer sinyaller kullanılır. Güven orta; tarihsel bağlam ve sözcük çok-anlamlılığı false positive oluşturabilir. Kaynak tarihi ve editoryal review tarihi manuel doğrulanmalıdır.

## 15. Kaynak/review metadata durumu

53.225 metadata gap / 61.358 = %86,75. Kaynak, review ve status alanlarından beklenenlerin eksikliği raporlanır. Güven alan-varlığı için yüksek; eski formatlarda alanın tasarım gereği bulunmaması bilinçli borç olabilir.

## 16. Görsel/asset sorunları

CSV'de 0 aday vardır; fakat bu sayı tam asset güvence sonucu değildir. Bu sürüm pubspec kapsamı, kullanılmayan görsel, dosya boyutu, uzantı ve kategori uyumunu uçtan uca uygulamaz. Mevcut repository testi yerel soru görsellerinin varlığını ayrıca doğrular. Dolayısıyla güven düşük ve false-negative riski yüksektir.

## 17. Kategori ve zorluk dağılımı

Kategori bilinmeyen: 10.000 / 61.358 = %16,30. En büyük bilinen kategoriler Ziman 6.292 (%10,25), Paradigma 5.537 (%9,02), Cografya 5.535 (%9,02). Zorluk bilinmeyen: 27.332 (%44,55); seviye 1-5'in her biri %10,52-%11,77 aralığındadır. Eşik boş/null alandır; güven yüksek.

## 18. Generated template sorunları

TODO, placeholder, lorem, JSON/Markdown ve model/prompt kalıntısı için yüksek güvenli eşleşme uygulanır; mevcut çıktıda 0 aday vardır. Yüzlerce kayıtlık semantik şablon kümelerini kesin çözen bir model yoktur; exact/near duplicate listeleri manuel şablon denetiminin ana girdisidir. False-negative riski orta-yüksektir.

## 19. Mevcut borç baseline'ı

Gate baseline'ı 13.571 fiziksel/kanonik kaydı, kaynak SHA-256 fingerprintlerini, issue fingerprintlerini ve dağılımları içerir: 3.501 BLOCKER, 4.968 CRITICAL, 20.606 WARNING, 0 unknown source. Baseline yalnız `--accept-current-debt` ile bilinçli yenilenir; borcu kaliteli ilan etmez.

## 20. Gate'in çalışma mantığı

Gate yalnız runtime/publish/aktif import rollerini okur. Unknown source, production-like eksikliği, parse hatası, kaynak fingerprint-baseline uyumsuzluğu, yeni stabil issue veya sayısal kötüleşmede exit 1 verir. Aynı borç ve iyileşme exit 0 verir. CI baseline yazmaz.

## 21. Yeni soru ekleme kabul kriterleri

Kaynak manifestte açık role sahip olmalı; parser kayıpsız çalışmalı; yeni BLOCKER/CRITICAL, exact duplicate, answer leak, critical divergence veya kayıp asset üretmemeli; kategori/zorluk/source/review/status metadata tamamlanmalı; Kurmancî metin insan editörce kontrol edilmelidir.

## 22. Önerilen manuel editoryal çalışma dalgaları

1. Gate kapsamındaki 31 invalid correct-answer ve yapısal blocker'ları doğrula.
2. Gate'teki answer leak ve Türkçe template adaylarını Kurmancî editörle incele.
3. Exact duplicate gruplarını kaynak/provenance bazında karara bağla.
4. Dinamik bilgi kayıtlarına kaynak ve review/expiry tarihi ekleme planı hazırla.
5. Metadata, kategori ve zorluk boşluklarını şema sahipleriyle çöz.

## 23. Değiştirilmemiş veri kaynakları

Hiçbir Dart/CSV/JSON/SQL soru kaynağı, Supabase dosyası, quiz runtime kodu, doğru cevap, seçenek, görsel veya soru ID'si değiştirilmedi. Otomatik çeviri, duplicate silme, push, merge ve deploy yapılmadı.

## 24. Açık kalan belirsizlikler

- SQL snapshot'ları yalnız sayım düzeyinde incelendi.
- Asset denetiminin ileri kontrolleri eksik.
- Answer-position yalnız global çıktı veriyor.
- Kurmancî dil ve semantik doğruluk insan uzman gerektiriyor.
- Near-duplicate listesi adaydır, kesin hüküm değildir.
- Report süresi bu makinede yaklaşık 169 saniyedir; CI maliyeti izlenmelidir.
- Manifest glob satırları resolved gerçek dosya yolu yerine pattern'i raporlayabilir.

## 25. Bir sonraki güvenli faz

Önce yalnız gate kapsamındaki en yüksek güvenli 31 correct-answer yapısal adayının salt-okunur editoryal teyidi yapılmalı; veri değişikliği ayrı branch, ayrı onay ve hedefli testlerle ele alınmalıdır. Faz 1'e bu rapor onaylanmadan geçilmemelidir.

## Metrik yorumlama sözleşmesi

| Metrik | Sayı / payda | Eşik | Güven | False positive riski |
|---|---:|---|---|---|
| BLOCKER | 59.901 / issue evreni | yapısal sözleşme | yüksek | düşük; issue'lar örtüşür |
| CRITICAL | 49.988 / issue evreni | exact/dil/dinamik kurallar | karma | orta |
| WARNING | 79.970 / issue evreni | aday/metadata kuralları | orta | orta-yüksek |
| Exact excess | 36.246 / 61.358 (%59,07) | normalize kimlik eşit | yüksek | snapshot kopyalarında orta |
| Near aday | 19.413 / 61.358 (%31,64) | token Jaccard | orta | yüksek |
| Unknown source | 0 / 44 kaynak (%0) | manifest eşleşmemesi | yüksek | düşük |
