# Content promotion

Karantinadaki soruları aktif bankaya taşımak için:

```bash
dart run tool/content_authoring/promote_question_bank.dart
```

Komut varsayılan olarak `supabase/wave2_quarantine_for_further_review.csv`
kaynağını, 15.000 aktif soru hedefini ve
`docs/audit/question_quality/2026-08-01/content_promotion/` çıktı klasörünü
kullanır.

Kalite kapısı şunları zorunlu tutar: onay durumu, sabit ID, canonical prompt
özgünlüğü, dört farklı seçenek, çözülebilir doğru cevap, Kurmancî dil uyumu,
zorluk, kaynak URL'si, kaynak doğrulaması, güven puanı, açıklama kalitesi,
şablon yoğunluğu ve kategori/zorluk dağılımı.

Hiçbir varsayılan değer eksik verinin yerine yazılmaz. En az bir aday bütün
kapılardan geçerse `expanded_questions.json` üretilir; aksi hâlde yalnız
manifest, ret CSV'si ve ölçümlü rapor yazılır.

`--fail-on-shortfall` CI veya yayın kapısında hedefe ulaşılamamasını hata kodu
olarak işaretlemek için kullanılabilir.
