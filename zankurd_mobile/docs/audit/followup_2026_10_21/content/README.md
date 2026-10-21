# İçerik borcu: 183 benzerlik uyarısının yerel incelemesi

2026-10-21; kapsam **yerel diskteki gate bankalarıdır**. Supabase sorgulanmadı. Üretim soruları, emekli soru listesi, göçler ve baseline değiştirilmedi.

## Sonuç

183/183 kayıt mevcut baseline parmak izleriyle birebir eşleşti. Bunların tümü `near_duplicate_candidate`, severity `warning`, otomatik güven `medium`: köklerin Jaccard benzerliğine dayanan inceleme adaylarıdır. **183 yanlış soru veya 183 kesin içerik kusuru anlamına gelmez.** Yerel gate tekrarında `baselinePasses=true`; 0 blocker, 0 critical, 183 warning korunuyor.

Çiftlerin kökleri, cevapları, soru türleri ve ders etiketleri üzerinden semantik tekrar incelemesi yapıldı:

| Karar | İncelenen kayıt |
| --- | ---: |
| `intentional_variation` — farklı nesne, ilişki, çekim veya bağlam | 166 |
| `redundant_repeat` — aynı kök hedefinin yeniden anlatımı | 10 |
| `needs_editorial_review` — kapsam/bağlam/kültür ayrımı kesinleşmeli | 7 |
| Toplam | 183 |

Bu yan rapor otomatik kalite borcunu sıfırlamaz, check'i değiştirmez ve izin listesi oluşturmaz. 166 varyant kararı yalnız tekrar şüphesini değerlendirir; olgu doğruluğunun veya bütün Kurmancî metnin insan editörce onayı sayılmaz.

## Başlangıç önceliği

`baslangic_2026_10_06_questions.json` 20, `dersler2_2026_10_08_questions.json` 8, `dersler3_2026_10_08_questions.json` 14: **42 çiftin tamamı incelendi ve ayrı ölçme hedefleri görüldü.** Örneğin `baslangic_..._0034` gül → `gul`, eş kayıt `_0033` kalem → `qelem` ölçer; ortak `Ev ___ e` kökü bu ayrımı ortadan kaldırmaz. Vücut soruları görme/işitme/koklama/yeme/tutma/yürüme işlevleriyle ayrılır. Geçmiş zaman sorularında kişi veya fiil değişir. `dersler3_..._0088` ile `ders_..._0051` uçma kavramını kullanır, fakat ulaşım aracı ile hayvan sözlüğünü ölçer.

Gerçek kullanıcının “ilk hafta” ders programı veya ekran gösterim günlüğü verilmedi. Yerel `everyday` kataloğunun ilk yedi dersi (alfabe, selamlaşma, nezaket, tanışma, kendini tanıtma, aile, günlük ifadeler) yalnız öncelik vekilidir; bu derslerle kaydın **veya karşı çiftin** etiketi üzerinden ilişkili 28 uyarı var. 42 başlangıç kaynağı uyarısı ile bu 28 ilişki aynı metrik değildir. Katalog kanıtı: `lib/src/data/mock_zankurd_repository.dart` içindeki `_lessonsData`; ilişki kanıtı sorunun `metadata.learningLessonId` alanıdır. 16 tamamlama paritesi izin listesi bu içerik incelemesinin onayı değildir.

## Kesin tekrar adayları ve küçük çözüm

`correction_candidates.json`, 10 açık aynı-hedef çiftini id/alan/eski/yeni/gerekçe/iki kaynak konumuyla kaydeder. Yeni Kurmancî çeviri veya farklı olgu uydurulmadı. Örnekler: Joseph Haydn'ın aynı lakabı; Hawar başlangıç yılı; Xoybûn/HDP kuruluş yılları; Şêx Seîd başlangıç yılı; Yılmaz Güney doğum yılı; Amed/Diyarbekir'den geçen aynı nehir; Selahaddin'in doğum yeri.

En küçük öneri, **ilerideki içerik üretim incelemesinde bu açık çiftleri aynı öğrenme hedefi grubu olarak kaydetmek ve üçüncü bir tekrar üretimini engellemek**. Mevcut iki ID korunur. Böylece konu/zorluk/soru türü kapsamı, geçmiş yanlışlar ve kayıtlı referanslar bozulmaz. Mevcut bir kaydın emekli edilmesi ayrı müfredat/kapsam ve referans kontrolü ister. Buradaki adaylar uygulanmış düzeltmeler değildir; genel runtime de-duplication önerilmez. Kesin dil/olgu düzeltmesi adayı 0; kesin aynı-hedef tekrar çifti 10.

7 açık editör kararı: GPS'in otomobil/uçak bağlamı; def/tembûr eşliği; Newroz ateşinin niteliği; nehir/deşt tanım koşulu; Mûsil sorusunun rapor eşinden başka üçüncü kaydı; düğün çalgılarının tek doğru yanıt varsayımı; genelleştirilmiş misafir ağırlama eylemleri. Bunlarda kaynak veya müfredat hedefi netleşmeden üretim metni değiştirilmez.

## İzlenebilir dosyalar

- `gate_snapshot.json`: mevcut `AuditEngine(gateOnly: true)` çıktısı; eski geniş arşiv raporunun sayılarıyla karıştırılmamalı.
- `triage_183.json`: her parmak izi için iki kök/yanıt, ders ilişkisi, önem, kategori, karar ve gerekçe.
- `triage_183.csv`: filtrelenebilir özet.
- `correction_candidates.json`: en fazla 10 hedef gruplama önerisi, hiçbir üretim değişikliği içermez.
- `summary.json`: toplamlar, kategori/ders dağılımı, kaynak SHA-256 kanıtı.
- `snapshot.dart`, `triage.py`: bu klasöre yazan tekrar üretim araçları.

Mevcut `tool/question_quality/adjudication/` incelendi. Modeli parmak izi/kaynak/kanıt/otomatik düzeltme güvenliği için örnek alındı; jeneratör invalid-answer, answer-leak ve duplicate-option incelemesine odaklanıyor, bu üç semantik near-duplicate kararını doğrudan desteklemiyor. Üretim adjudication/check kodunu genişletmek yerine bağımsız `reviewDecision` alanı kullanıldı.

## Tekrar üretim ve sınırlar

Flutter proje kökünden:

```sh
dart run docs/audit/followup_2026_10_21/content/snapshot.dart
python3 docs/audit/followup_2026_10_21/content/triage.py
```

Standart CLI `report` komutu eski `docs/audit/question_quality/2026-07-15` klasörüne sabit yazdığı için çalıştırılmadı. Bulunan geniş arşiv `summary.json`, kendi gate alt özetinde yine 183 warning gösteriyor; arşiv köklerinin yüz binlerce fiziksel/kopya bulgusu bu çalışmanın üretim kapsamı değildir. Tam Flutter testleri çalıştırılmadı; bu yalnız yan rapor/veri incelemesidir. Harici olgu kaynağı açılmadı; yerel kayıt karşılaştırması bağımsız kaynak doğrulaması olarak sunulmaz.
