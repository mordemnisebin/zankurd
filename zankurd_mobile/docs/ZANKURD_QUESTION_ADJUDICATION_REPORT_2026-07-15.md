# ZanKurd Soru Adjudication Raporu — 2026-07-15

## 1. Executive summary

Faz 0C.1, Faz 0B'nin en yüksek öncelikli 31 invalid correct-answer ve 62 answer-leak adayının tamamını orijinal kaynak kayıtlarıyla eşleştirdi; ayrıca 22.538 duplicate-option bulgusundan 200 satırlık deterministik katmanlı örneklem inceledi. Toplam 293 review satırının tamamında kaynak bulundu, `safeForAutomaticFix=true` sayısı sıfır kaldı ve hiçbir production verisi değiştirilmedi.

En önemli sonuç, 31 invalid doğru-cevap adayının hiçbirinin gerçek invalid cevap olmamasıdır. 15'i parser/auditor false positive, 16'sı aynı sorunun fiziksel kopyasıdır. Gerçek veri sorunu, bu kayıtların bir bölümündeki duplicate seçeneklerdir; doğru cevap harfi geçerlidir.

## 2. İncelenen branch ve commit

- Başlangıç: `codex/phase0b-question-quality-gate-2026-07-15` / `b8919fef7ffef871871721d4396eb45f90cc2c11`
- Çalışma branch'i: `codex/phase0c1-question-adjudication-2026-07-15`
- Araç commit'i: `1c2131e`
- Test commit'i: `63ae9fb`

## 3. Kullanılan Faz 0B girdileri

`structural_issues.csv`, `blockers.csv`, `critical_issues.csv`, `answer_leaks.csv`, `exact_duplicates.csv`, `cross_source_copies.csv`, `cross_source_divergences.csv` ve `source_inventory.csv` bulundu. Review kararı yalnız rapor satırına dayanmadı; her kayıt source manifest, gerçek dosya, fiziksel satır, ID, ham correct alanı ve Faz 0B parser sonucu üzerinden yeniden eşleştirildi.

## 4. 31 invalid correct-answer adayının sonucu

| Adjudication | Sayı | Oran |
|---|---:|---:|
| `parser_false_positive` | 15 | %48,39 |
| `cross_source_copy_artifact` | 16 | %51,61 |
| Gerçek invalid doğru cevap | 0 | %0 |

28 fiziksel satırda A/B/C/D harfi geçerli bir seçeneğe çözülür; case-insensitive duplicate seçenek yüzünden `invalid_correct_answer` ikinci kez tetiklenir. Üç candidate satırında `?:`, `??` ve `?` terminal noktalama normalizasyonuyla boş/eşdeğer hale gelir. Parser seçenek sırasını değiştirmemiştir; CSV quoting veya Unicode kayıt kaybı yoktur.

## 5. Confirmed data defect sayısı

Review çıktılarında 73 fiziksel `confirmed_data_defect` vardır: 13 answer leak ve duplicate örneklemindeki 60 gate/publish kaydı. Bu sayı tekil kanonik defect sayısı değildir ve 200 satırlık örneklem dışına kesin genellenmemelidir.

## 6. Parser false positive sayısı

Toplam 21: invalid-answer 15, answer-leak 3, duplicate-option 3. `invalid_correct_answer` kontrolü geçerli doğru cevap ile duplicate seçenek çokluğunu birbirine karıştırıyor; punctuation normalization ise anlamlı sembol seçeneklerini siliyor.

## 7. Source schema mismatch sayısı

Sıfır. İncelenen doğru cevapların tümü A-D harfi biçimindedir; 0/1 tabanlı veya metin tabanlı schema uyuşmazlığı gerçek adaylarda görülmedi. Yardımcı araç bu biçimleri sentetik testlerle ayrı doğrular.

## 8. Historical/copy artefakt sayısı

Toplam 186 fiziksel satır: invalid 16, leak 33, duplicate örneklemi 137. Aynı ID+soru, `canonicalGroup` farklı olsa bile adjudication kopya kimliğinde birlikte değerlendirilmiştir.

## 9. Belirsiz insan editörü gerektiren sayı

`ambiguous_needs_editor` sıfırdır; ancak 13 kayıt ayrıca `factual_verification_required` ve 114 review satırı `KurmanciEditorNeeded=true` taşır. Bu ikinci sayı fiziksel satırları içerir ve kopyalar nedeniyle tekil soru sayısı değildir.

## 10. 62 answer-leak adayının sonucu

| Adjudication | Sayı | Oran |
|---|---:|---:|
| `confirmed_data_defect` | 13 | %20,97 |
| `factual_verification_required` | 13 | %20,97 |
| `parser_false_positive` | 3 | %4,84 |
| `cross_source_copy_artifact` | 33 | %53,23 |

## 11. Gerçek leak sayısı

13 fiziksel asıl kayıt doğrulandı. Bunların 10'u runtime-active offline görsel sorularında kategori/cevabın promptta açıkça yazılmasıdır. Üçü candidate pool'da başlık veya oyun adının cevap olarak aynen görünmesidir. Kopya satırlar ayrıca gerçek leak sayısına eklenmedi.

## 12. Leak false-positive nedenleri

Üç asıl false positive vardır: `doğru` seçeneğinin “doğru anlam” doğal ifadesi içinde geçmesiyle iki kayıt ve cümledeki fiili sormak için fiilin zorunlu olarak örnek cümlede görünmesiyle bir kayıt. 13 coğrafi/tarihsel kayıt yalnız lexical eşleşmeyle karara bağlanmadı; otoritatif kaynak gerektirdiği için factual review'a ayrıldı.

## 13. Duplicate-option örneklem büyüklüğü

200 / 22.538 fiziksel bulgu (%0,89) incelendi. Örneklem sourceId, sourceRow ve stabil issue fingerprint sırasıyla deterministiktir. Runtime primary/secondary ve Dart parser'da duplicate-option popülasyonu sıfır olduğundan bu tabakalardan örnek alınamamıştır; bu bir kapsam daraltması değil, sıfır popülasyon durumudur.

## 14. Örneklem doğrulama oranları

197/200 (%98,5) gerçek duplicate biçimidir; Wilson %95 güven aralığı yaklaşık %95,7-%99,5. Üç kayıt (%1,5) punctuation-normalization false positive'dır. Biçimler: 193 exact, 4 case-only, 3 punctuation collision. Bu oran tüm 22.538 kayıt için kesin hüküm değildir.

## 15. Parser türüne göre sonuçlar

Duplicate popülasyonunda yalnız CSV parser vardır: 197/200 gerçek duplicate (%98,5), 3/200 false positive. Dart/JSON/SQL parser duplicate-option popülasyonu sıfırdır; oran üretmek istatistiksel olarak geçersiz olur.

## 16. Kaynak rolüne göre sonuçlar

| Rol | Örnek | Gerçek duplicate | Oran | Yaklaşık Wilson %95 GA |
|---|---:|---:|---:|---:|
| import_candidate | 58 | 58 | %100 | %93,8-%100 |
| publish_candidate | 2 | 2 | %100 | %34,2-%100 |
| historical_snapshot | 50 | 50 | %100 | %92,9-%100 |
| quarantine | 45 | 45 | %100 | %92,1-%100 |
| candidate_pool | 45 | 42 | %93,3 | %82,1-%97,7 |

Publish adayı örnek sayısı yalnız iki olduğu için güven aralığı geniştir. Kopya rollerindeki gerçek duplicate'lar `cross_source_copy_artifact` olarak sınıflandırılmıştır.

## 17. Cross-source doğru-cevap sapmaları

Bağımsız reconciliation taramasında aynı ID, aynı prompt/options veya seçenek sırası değişimi nedeniyle farklı correct index/text adayı sıfırdır. Faz 0B'nin 22.444 WARNING divergence'ı kategori, açıklama, zorluk veya status farkıdır; doğru-cevap BLOCKER'ı gibi sunulmamıştır.

## 18. Runtime erişilebilirliği

- `offline_runtime_bank` ve `curated_runtime_bank`: `runtime_active`; `MockZanKurdRepository.questions` iki bankayı içerir ve Supabase repository hata/boş sonuçta aynı offline repository'ye düşer.
- `active_import_ready`: `import_active_not_runtime`; üretim/import aracına girdidir, uygulama dosyayı doğrudan okumaz.
- `wave2_publish_candidates`: `publish_candidate_not_runtime`; SQL export aracıyla ilişkilidir, runtime dosyası değildir.
- Live export CSV: import scriptleriyle ilişkilidir ancak uygulama runtime'ı dosyayı doğrudan okumaz; konservatif olarak `unknown` bırakılmıştır.
- Historical/quarantine kaynaklar kendi erişilebilirlik sınıflarında tutulmuştur.

## 19. Factual verification gereken kayıtlar

13 asıl kayıt: Mahabad Cumhuriyeti'nin merkezi, şehir-devlet/ülke başkent eşleşmeleri ve resmi/ulusal dil türü sorular. Kaynak içindeki cevap değiştirilmedi; güncel veya tarihsel otoritatif kaynak teyidi gereklidir.

## 20. Kurmancî editör gereken kayıtlar

114 fiziksel review satırı işaretlidir. En yüksek öncelik 10 runtime-active görsel leak'i ile 58 active-import duplicate distractor bulgusudur. Kopyalar tek tek değil kanonik asıl kayıt üzerinden ele alınmalıdır.

## 21. Önerilen ilk düzeltme dalgası

Katı `recommended_fix_wave_1.csv` sonucu sıfırdır. Doğrulanmış sorunların hiçbiri editoryal karar olmadan doğru yeni metin/distractor üretmeye izin vermez. Güvenli sıra:

1. Faz 0C.2A'da yalnız auditor discovery/normalization false-positive paketini düzelt.
2. Kurmancî editörle 10 runtime visual leak için yeni prompt önerilerini hazırla.
3. 58 active-import duplicate option için distinct distractor önerilerini ayrı insan onayına sun.
4. 13 factual kaydı otoritatif kaynaklarla doğrula.

## 22. Değiştirilmeyen production verileri

Hiçbir Dart/CSV/JSON/SQL soru kaynağı, Supabase dosyası, baseline, source manifest, CI workflow, quiz runtime, repository/provider, asset veya platform dosyası değiştirilmedi. `safeForAutomaticFix` bütün kayıtlarda false'tur.

## 23. Denetim aracında bulunan muhtemel bug'lar

1. `invalid_correct_answer`, doğru harf geçerli olsa bile normalize duplicate seçenek varsa yanlış BLOCKER üretir.
2. Terminal punctuation normalization `?:`, `??`, `?` gibi anlamlı seçenekleri boş/eşit hale getirir.
3. Lexical answer-leak kontrolü doğal `doğru anlam`, örnek cümle ve coğrafi ad bağlamlarını ayıramaz.
4. Başlangıç commit'i `b8919fe` içindeki iki Faz 0B yönetici `.md` raporu, discovery'nin path sinyaliyle yeni soru kaynağı sayılır. Gate `unknown=2` ile başarısızdır. Bu Faz 0C.1'in izin verilen kapsamı dışında olduğu için discovery/manifest düzeltilmemiştir.

Gate bug'ının kesin tekrarı: `dart run tool/question_quality/question_quality_audit.dart gate`; mevcut sonuç `Unclassified question source detected.` Beklenen sonuç, yönetici raporlarının soru kaynağı keşfine girmemesi ve başlangıç baseline'ında exit 0'dır.

## 24. Güven ve false-positive sınırları

Yapısal harf/index eşleştirme güveni yüksektir. Answer-leak semantik/factual kararlarında güven orta, duplicate örneklem oranında %95 Wilson aralığı verilmiştir. Örneklem 22.538 satırın tamamını kanıtlamaz; fiziksel kopyalar bağımsız editoryal hata gibi sayılmamalıdır. Hiçbir gerçek doğru cevap genel bilgiyle değiştirilmemiştir.

## 25. Sonraki güvenli adım

Önce Faz 0C.2A adlı ayrı auditor-fix branch'iyle dört araç kusuru ele alınmalı; source manifest/baseline değişikliği ayrı onay ve gate baseline semantiği incelemesi gerektirir. Ardından yalnız insan tarafından onaylanmış runtime leak/distractor önerileri için veri düzeltme branch'i açılmalıdır.
