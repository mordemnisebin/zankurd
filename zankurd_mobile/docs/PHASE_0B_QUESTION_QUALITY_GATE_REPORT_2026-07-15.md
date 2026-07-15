# Faz 0B — Soru Kalitesi Kapısı Kapanış Raporu — 2026-07-15

## 1. Başlangıç branch ve HEAD

`codex/phase0a-release-gates-2026-07-15` / `f58eba40eb76dbdebd4e43dccc82001b595d2456`.

## 2. Yeni branch

`codex/phase0b-question-quality-gate-2026-07-15`.

## 3. Değişen dosyalar

Yalnız `tool/question_quality/**`, `test/question_quality/**`, `docs/audit/question_quality/**`, iki Faz 0B raporu, `README.md` ve `.github/workflows/flutter_ci.yml` değiştirildi. Tasarım belgesi ayrıca `docs/ZANKURD_QUESTION_QUALITY_GATE_DESIGN_2026-07-15.md` olarak eklendi.

## 4. Keşfedilen soru kaynakları

44 manifest eşleşmesi bulundu; unknown source 0, kayıp production source 0. Roller ve tam envanter `docs/audit/question_quality/QUESTION_SOURCE_INVENTORY_2026-07-15.md` ile tarihli `source_inventory.csv` içindedir.

## 5. Gerçek soru sayıları

Report: 102.460 fiziksel, 61.358 parse edilmiş, 38.629 kanonik tekil. SQL count-only farkı 41.102 kayıttır. Gate: 13.571 fiziksel/parse/kanonik. Report-only fiziksel kayıt: 88.889.

## 6. Runtime'da kullanılan kaynaklar

`offline_runtime_bank` 3.125; `curated_runtime_bank` 20; `live_kurmanci_export` 377. Gate ayrıca `active_import_ready` 10.000 ve `wave2_publish_candidates` 49 kaydı içerir.

## 7. Auditor mimarisi

Manifest çözümleme, keşif, CSV/JSON/Dart/SQL-count reader'ları, Kurmancî-korumalı normalization, kanonikleştirme, cross-source reconciliation, kalite kontrolleri, baseline karşılaştırma ve deterministik CSV/JSON/Markdown writer katmanlarından oluşur. Runtime Question modeli değiştirilmedi.

## 8. Report/gate/baseline modları

- `report`: bütün sınıflandırılmış report kaynaklarını raporlar.
- `gate`: yalnız production-like gate kapsamını baseline'a göre değerlendirir.
- `baseline --accept-current-debt`: açık kabul olmadan yazmaz; CI bunu çağırmaz.

## 9. BLOCKER sayısı

Report 59.901; gate 3.501. Issue sayıları örtüşebilir ve tekil kötü soru sayısı değildir.

## 10. CRITICAL sayısı

Report 49.988; gate 4.968.

## 11. WARNING sayısı

Report 79.970; gate 20.606.

## 12. Exact duplicate grup ve fazla satır sayısı

24.412 stabil issue grubu ve 36.246 fazla satır. Cross-source copy grubu 22.458'dir.

## 13. Near duplicate aday sayısı

Tekilleştirilmiş 19.413 aday. Bunlar kesin duplicate olarak yorumlanmamalıdır.

## 14. Dil karışımı adayları

5.530 yüksek güvenli Türkçe-template adayı. Heuristik kontrol Kurmancî gramer doğruluğu iddiasında bulunmaz.

## 15. Answer leak sayısı

62 aday.

## 16. Correct-answer yapısal sorunları

31 invalid correct-answer ve 22.538 duplicate-option issue saptandı. Veri otomatik düzeltilmedi.

## 17. Cevap pozisyonu dağılımı

A 28.309 (%46,14), B 18.288 (%29,81), C 7.868 (%12,82), D 6.893 (%11,23), payda 61.358. Bu sürüm global dağılım üretir; ayrıntılı kaynak/kategori kırılımı açık eksiktir.

## 18. Kaynak/review metadata eksikleri

53.225 issue (%86,75).

## 19. Dynamic fact adayları

8.150 issue (%13,28); manuel kaynak ve review-date kontrolü gerekir.

## 20. Görsel/asset sorunları

Üretilen CSV 0 satırdır; ancak ileri pubspec, unused asset, boyut, uzantı ve kategori uyumu kontrolleri uygulanmadığı için bu sonuç tam asset güvencesi değildir.

## 21. Baseline içeriği

Manifest sürümü, SHA-256 kaynak fingerprintleri, gate sayımları, rol/severity dağılımları, stabil issue fingerprintleri, duplicate/divergence/leak/correct-answer/asset/unknown metrikleri ve A-D/kategori/zorluk dağılımları. Güncel gate borcu: 3.501 BLOCKER, 4.968 CRITICAL, 20.606 WARNING.

## 22. CI davranışı

`flutter_ci.yml`, Widgetbook analyze sonrasında ve testlerden önce `dart run tool/question_quality/question_quality_audit.dart gate` çalıştırır. Report ve baseline CI'da çalışmaz; binlerce soru metni loglanmaz.

## 23. Eklenen testler

Manifest precedence/çatışma/unknown source, discovery dışlamaları, CSV/JSON/Dart reader, parse hatası, Kurmancî Unicode, fingerprint, kanonik sayım/divergence, yapısal kontroller, exact/near duplicate, token cache/tekilleştirme, Türkçe template, answer leak, dynamic fact, generated residue, açıklama tekrarı, CSV injection ve baseline regresyon semantiği kapsandı.

## 24. Toplam test sonucu

- Soru kalitesi paketi: 30/30 geçti.
- Tam `flutter test --exclude-tags preview`: 581/581 geçti.

## 25. Analyzer sonuçları

- `dart format --set-exit-if-changed`: 18 dosya, 0 değişiklik.
- Kök `dart analyze`: No issues found.
- Widgetbook `dart analyze`: No issues found.
- Dar auditor analyze: No issues found.

## 26. Web build sonucu

`flutter build web` exit 0; `build/web` üretildi. Komutun WASM dry-run kontrolü de başarılı oldu. Artifact yalnız ignored build dizinindedir; yayınlanmadı, kopyalanmadı ve deploy edilmedi.

## 27. Determinizm doğrulaması

Report art arda çalıştırıldı. `run_metadata.json` hariç 24 sabit çıktı dosyasının SHA-256 karşılaştırmasında değişen dosya sayısı 0'dır. Güncel report süresi yaklaşık 169 saniyedir.

## 28. Değiştirilmeyen soru/veri dosyaları

Hiçbir Dart/CSV/JSON/SQL soru kaynağı, Supabase içeriği, offline banka, quiz runtime, doğru cevap, seçenek, ID, kategori, zorluk veya görsel değiştirilmedi. Forbidden path diff'i kapanışta ayrıca sıfır doğrulanacaktır.

## 29. Ana checkout kanıtı

Ana checkout'a build/test yazılmadı. Korunması gereken tek mevcut durum: ` M macos/Flutter/GeneratedPluginRegistrant.swift`.

## 30. Commit listesi

- `d7fd18f docs: define question quality gate design`
- `4d5d820 feat: add source manifest and question auditor`
- `c68b369 test: cover question quality gate`
- `b58bf23 ci: prevent question source regressions`
- `7a08a05 fix: deduplicate near question candidates`
- `1314b46 feat: expand editorial risk heuristics`
- Bu rapor ve deterministik çıktılar ayrı `docs: add question quality audit report` commit'inde kapanacaktır.

## 31. `git status --short`

Rapor commit'i ve son doğrulama sonrasında boş olması kabul kriteridir. Ana checkout yalnız izin verilen Swift satırını göstermelidir.

## 32. Önerilen ilk manuel düzeltme dalgası

Öncelik gate kapsamındaki 31 invalid correct-answer adayının salt-okunur editoryal teyididir. Ardından answer leak, Türkçe template ve kritik divergence adayları ayrı küçük dalgalarda ele alınmalıdır.

## 33. Cross-source reconciliation

22.458 copy grubu ve 22.444 divergence bulundu. Divergence'ların tümü WARNING: 7.500 açıklama/kategori/zorluk/status, 7.500 açıklama/zorluk/status, 2.500 kategori/zorluk/status, 2.500 zorluk/status, 2.444 yalnız status farkı.

## 34. Kategori ve zorluk özeti

10.000 kayıtta kategori bilinmiyor (%16,30); 27.332 kayıtta zorluk bilinmiyor (%44,55). En büyük bilinen kategori Ziman: 6.292 (%10,25).

## 35. Güvenlik ve gizlilik

CSV writer formula-injection başlangıç karakterlerini escape eder. Secret/service-role key veya kullanıcı özel verisi rapora bilinçli olarak eklenmedi; kapanışta hedefli secret/path taraması yapılacaktır.

## 36. Bilinen sınırlamalar

SQL yalnız fiziksel count, asset kontrolü kısmi, answer-position yalnız global, dil/near-duplicate/dynamic kontroller heuristik, manifest glob çıktısı resolved yol yerine pattern gösterebilir ve report CI için ağır olabilir.

## 37. Yayın işlemleri

Push, merge, deploy, Supabase yazma, release artifact yayınlama veya kopyalama yapılmadı.

## 38. Sonuç

Faz 0B çalışan, testli ve deterministik bir regresyon kapısı üretmiştir. Gate'in yeşil olması mevcut editoryal borcun çözüldüğünü değil, baseline'a göre kötüleşme olmadığını gösterir. Sonraki veri düzeltme fazı açık kullanıcı onayı beklemelidir.
