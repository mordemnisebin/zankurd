# T10 — Tur 6 yerel düzeltme ve kanıt raporu

Başlangıç: `77213626` (T8 birleşimi). Kaynak bulgular: `/Users/kocer/Projects/zankurd_kapisma/tur6/RAPOR.md`.

Canlı Supabase bağlantısı, gerçek hesap oluşturma, mağaza ve push yok. Gizli/env dosyaları okunmadı. Simülatör sınırı A `78303C59`, B `08B706E0`.

| Madde | Kök | Değişiklik | Bekçi |
|---|---|---|---|
| 1 Oda sayaç/sayı | Sunucu saati zaten ortaktı; cevaptan sonra animation duruyor. Uçuşta reconcile yeni olayı yutuyor. 6 sn ayrı sayı yoklaması ve cevapsız istemcinin reveal sinyalini kaçırması | Ortak deadline cevap sonrası da akar; reveal başlangıcında durur. Kuyrukta tek ek reconcile. 1 sn hafif sayı/faz RPC, en fazla 3 uçuş/4 sn timeout; eski yanıt reddi. İstemciye özel reveal-advance gecikmesi kaldırıldı | `t10_room_sync_test.dart`: 4 gerçek QuizScreen; ±5 sn duvar saati, 0–2 sn aktarım/olay gecikmesi; t9'da tümünde 11±1 sn ve 2/4; sonraki soru; eski snapshot ve eski sayı |
| 2 Oturum | 6bf86832→77213626 auth/init/iOS bundle/entitlements/SDK lock değişmiyor | Üretim auth değiştirilmedi; gerçek eski/yeni derleme, localhost sahte misafir ve üstüne kurulum kanıtı aşağıda | `auth_upgrade_persistence_t10_test.dart`; A native test |
| 3 Sırayla sonuç | Oyun sonucu pushReplacement sonrası doğrudan afterGame açıyordu | Oyunu sayma ve istemi gösterme ayrıldı; pending görev sonuç kapanışına taşındı, bekleme→kesin sonuçta aktarılır | `async_duel_gorev_ilerletme_test.dart`, `async_duel_bekleme_yenileme_test.dart` |
| 4 Sahte 4/4 | SQL player_answers içindeki TIMEOUT kayıtlarını sayıyor | Yeni korumalı canlı-tanım yaması yalnız A/B/C/D sayar; yalnız güvenli revealed faz bilgisi eklenir | SQL sözleşmesi + 4 istemci TIMEOUT0/4 ve oyuncu olayı olmadan reveal |
| 5 Hükmen sıralama | Sıralama completed bilgisini etikete geçirmiyordu | Elenen/tamamlanan kayıt Oynamadı · hükmen; uzun etiket alt satırda | `tournament_bracket_presentation_test.dart` |
| 6 Aşama simgesi | Bayat round.status; tamamlanan maçlardan durum türetilmiyordu | Tamamlanan turnuva veya turdaki tüm tamamlanan maçlar onay simgeli | Aynı testte iki ayrı terminal durum |
| 7 Kayıt | onPressed yalnız loading denetliyordu; alt başlık eposta/parolaya özgüydü | İlk iki adım gerekli alanlar boşken pasif; metin değişiminde güncellenir; mevcut kapsayıcı saveAccountSub tekrar kullanılır | `sign_up_validation_test.dart`, mevcut T4 auth seçenek/sığma testleri |
| Zevk (Sen) | Kendi satırı yalnız renkle ayrılıyordu | Ayrı, isim ellipsisinden etkilenmeyen (Sen)/(Tu) + semantics | Turnuva TR/KU bekçisi |
| Zevk maskot | Bulgu yeniden üretilemedi; mevcut kaynak ve render support/uzgun.svg, aşağı kıvrımlı ağız gösteriyor | Gereksiz varlık değişmedi; gerçek kayıp sonucu render edildi | `quiz_result_header_contrast_test.dart`, web/native kayıp karesi |
| Zevk hikâye | TR yardımcı metinler koşulsuz çiziliyordu | KU'da anlatım/seçim/geçmiş/kelime/mini rehber TR karşılıkları gizli, semantics de KU | `story_choice_language_test.dart` TR/KU |

## SQL

`supabase/2026-10-30_t10_room_answer_count.sql` **uygulanmadı**, applied.md **⏳**. Eski RPC gövdesini kopyalamaz; uygulama anında pg_get_functiondef ile mevcut tanımı alıp tam eşleşmeli ve idempotent iki dar yama yapar. Üyelik, SECURITY DEFINER, search_path ve yetkiler korunur; puan/deadline/advance verisi değiştirilmez. Tamamen yanlış/timeout turunda room_players skor/streak değişmediği için realtime susabilir; yeni revealed boolean bunu hafif sorguyla yakalar. Doğru cevap veya oyuncu seçimi sızmaz.

Yerel SQL sözleşme testi geçti; çalışan yerel PostgreSQL bulunmadığı için SQL transaction dumanı çalıştırılmadı. Canlı uygulamadan önce canlı diff + begin/rollback üyelik/timeout/ikinci uygulama dumanı gerekir. SQL uygulanana kadar canlı TIMEOUT sayımı ve yeni revealed alanı düzelmiş sayılmaz.

## Dil

Yeni KU dizesi eklenmedi. Önceden kullanılan dizeler yeniden kullanıldı:

| Konum | TR | KU |
|---|---|---|
| Kayıt alt başlığı | Hesabını kalıcı yap: Apple, Google ya da e-posta ile. | Hesabê xwe mayînde bike: bi Apple, Google an e-nameyê. |
| Hükmen | Oynamadı · hükmen | Nelîst · têkçûna bi biryarê |
| Kendi satırı | (Sen) | (Tu) |

Yeni alternatif alt başlık taslağı denenmiş, Gemini değişiklik önermiş; Grok kota sınırı nedeniyle ikinci onay alınamamıştır. Taslak ürüne eklenmemiştir. Mevcut doğrulanmış saveAccountSub kullanılır.

## İnceleme ve görsel kanıt

Gemini 4 Argon High iki kod/SQL incelemesinde onay verdi (`gemini_review.txt`, `gemini_final_review.txt`). Son nottaki iptal edilen progress timer referansını null yapma ve SQL revealed doğrulaması eklendi. Sunucu tarafında room_players yalnız değişen score/streak için güncellenir; tüm yanlış turunda yeni faz sorgusu gereklidir.

Son uzlaştırma döngüsü düzeltmesi ayrıca Gemini 4 Argon High tarafından incelendi: kendi kendini kuyruğa alma kesiliyor, dış olaylar korunuyor (`gemini_reconcile_review.txt`).

Web: production widget'ları kullanan `tool/t10_web_preview.dart`, Supabase başlatılmaz. 320/390/768 px; TR/KU; 1.3 metin ölçeği. Playwright: boş İleri/Pêş disabled, Google/misafir/giriş görünür, konsol hatası 0. Apple native iOS doğrulamasındadır (web'de platform koşulu gereği yok).

Kareler bu klasörde `web_*.png` ve `native/`; öncesi kareleri Tur6 raporunda. Webde kayıt, turnuva şeması/sıralama ve tamamlanmış şerit, kayıp sonucu, sırayla sonuç, KU hikâye gözle incelendi. Büyük KU metninde hükmen alt açıklaması taşmadan sarılır.

## Son doğrulamalar

- Tam CI ek uyumsuzlukları yakaladı: kullanılmayan `stepCredentials` anahtarı kaldırıldı; hikâye içerik çiftleri tek yardımcıya alındı (l10n tavanı artırılmadı); kalabalık oda fixture'ında realtime ve snapshot puanı aynı kaynaktan üretiliyor. Dil/hikâye 14/14, kalabalık oda 38/38 geçti.
- Uzlaştırma kuyruğu için ek regresyon: pending snapshot kendi `_checkMultiplayerSync` çağrısıyla tekrar kuyruğa girip microtask döngüsü oluşturabiliyordu. Snapshot içi yeniden istem engellendi; dış answered/finished/index olayları kuyruklanır. `quiz_server_session_contract_test.dart` CAS bekçisi 20 istek sınırıyla döngüde asılı kalmadan hata verir. Son oda/CAS/4 istemci kümesi 60/60 geçti.
- Odak oda/düello: 40 test geçti.
- Dört istemci: 4/4 geçti.
- UI regresyonları: 71/71 geçti.
- Kayıt/SDK saklama: 51 test geçti. Tam CI'nin yakaladığı eski `entry_scaffold_test` alan dolumundan sonra yeni etkinleşme karesini bekleyecek şekilde güncellendi; konum/buton beklentileri gevşetilmedi, 9/9 geçti.
- Soru bankası değişmedi; kalite borcu kabulü/baseline güncellemesi yapılmadı. Yeni görsel fixture kaynak envanterine test_fixture olarak eklendi.
- Native B: kayıt (Apple/Google görünür, İleri pasif), turnuva şeması/sıralama ve onay şeridi, sırayla sonuç, KU hikâye, üzgün kayıp maskotu gözle doğrulandı. Oda cevabı seçili ve kilitliyken aynı 2/4 sayısı ile sayaç iki karede 14→7 aktı (`B_room_selected_early/later.png`).
- A oturum: `6bf86832 → 77213626 + T10 kaynak snapshot` yerel üstüne kurulum geçti; 1 signup, 0 refresh, yükseltme sonrası 23/23 istek aynı misafir oturumuyla. Son ağaçla auth dosyaları birebir. Ayrıntı/sınır: [session_upgrade.md](session_upgrade.md). Tur6'daki gerçek A olayının nedeni belirlenemedi.
- A önceki app/data/AppGroup, B önceki app geri yüklendi. B harness SharedPreferences bellekte çalıştı; gerçek oturum verisi kullanılmadı/değiştirilmedi. Uygulamalar canlıya bağlanmamak için kapalı bırakıldı.
- Tam CI **yeşil** (exit 0): ekran turu **214**, tam paket **7.216 geçti / 3 atlandı**, cihazsız akışlar **4/4**. U13, sığma/kayma, renk ve giriş seçenekleri bekçileri dahil. Son satır: `CI yerel: bütün adımlar geçti.` [CI özeti ve günlük parmak izi](ci_summary.txt).
