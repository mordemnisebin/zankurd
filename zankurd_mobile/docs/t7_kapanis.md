# T7 — kapanış turu 5

Kaynak rapor: `/Users/kocer/Projects/zankurd_kapisma/tur5/RAPOR.md` ve tur5 kareleri.
Canlı veritabanına bağlanılmadı; gizli dosyalar okunmadı; push yapılmadı.

| Madde | Değişiklik | Bekçi / kanıt |
|---|---|---|
| C12 | `Player.joinedAt` ilk yüklemeden canlı güncellemeye korunur. Her snapshot `joined_at`, eşitlikte `player_id` ile yeniden sıralanır. Eksik/bozuk zaman sunucu satırından tamamlanır. Ekranın host-first yeniden sıralaması kaldırıldı. | `t7_c12_room_order_test`: iki istemci, farklı INSERT/UPDATE varışları, eksik zaman fetch, hata yolları. Native lobide Ali/Bero/Cano/Dlan; host Dlan son sırada. |
| D22 | Puan, XP, jeton, sıralama, haftalık ve diğer tam sayı gösterimleri ortak `groupThousands` üzerinden TR/KU noktayla yazılır. | `tur5_number_format_test`: ham enterpolasyon/toString kaynak bekçisi, bekçinin negatif örnekleri, TR/KU sonuç/ödül/haftalık ekranları. Native 1.202–888, +1.202 XP, 1.436/2.500 XP, 4.404 haftalık. |
| U13 | Puan ayrı satırda 14 taban boyutu; seri ve kendi tarafı işareti ayrı sabit yükseklikte. Metin küçülten FittedBox kaldırıldı; avatar gerçek ayrılan genişliğe göre saklanır. | `t7_readability_test`: 320/375/402 ve 800×600, ×1.0/1.3, TR/KU, 99.999 ve ×5, gerçek font boyutu ve 0→5 konum kararlılığı. Sigma/kayma/tur3 bekçileri; native TR/KU ×1.3. |
| 4 | Apple/Google hesap kaydetme düğmeleri “ile devam et”; KU ortak `bi … re bidomîne` kalıbı. | T7 auth widget, guest save/link ve dil bekçileri; native ve Playwright auth karesi. |
| 5 | Turnuva finalindeki kendi oyuncu tarafına `Sen` / `Tu` eklendi. | `turnuva_sunucu_puani_istemci_test`, gerçek `TournamentScreen` native final kartı. |
| 6 | Turnuva yanıt açılışında sayaç `–`; sonraki soruda sayı yeniden görünür. | Aynı turnuva testi: sayı→çizgi→sayı; native doğru yanıt ve çizgi birlikte. |
| 7 | Berxwedan kaydı Paradigma→Ziman. Bookchin çeldiricisi Thomas Hobbes olarak TR/KU taslaklandı. | `t7_content_category_test`, banka bekçileri, kalite borcu 0→0; [içerik/KU tablosu](t7_icerik.md). |

Yerel berxwedan kaydı JSON'da değil `lib/src/data/curated_question_bank.dart` içindedir; gerçek kaynak düzeltildi. Bookchin sorusu aktif yerel bankada yoktur; tarihsel bankaya yeniden eklenmedi.

## SQL

[2026-10-30_anlam_kategori_celdirici.sql](../supabase/2026-10-30_anlam_kategori_celdirici.sql): iki kesin kimlik/alanı korumalı, idempotent transaction; eski değer/kimlik ve sonuç doğrulama blokları var. `applied.md` ⏳. **Uygulanmadı**; PostgreSQL üzerinde çalıştırma kanıtı yoktur.

## Bağımsız inceleme

Üretim değişiklikleri Gemini 4 Argon tarafından incelendi. Sayı bekçisinde bulunan üç kaçış kapatıldı. KU için Gemini 3.8 Flash ve Gemini 4 Argon aynı son metni önerdi/onayladı; Grok 4.7 kota sınırı nedeniyle yanıt vermedi. Tercih edilen Gemini+Grok çifti sağlanamadığı açıkça [KU tablosunda](t7_icerik.md) kayıtlıdır.

## Görsel doğrulama

`integration_test/t7_native_visual_test.dart` mock repository ile iOS simülatörde dokuz üretim ekranı/bileşen görünümünü doğrular. `tool/t7_web_preview.dart` aynı UI için çevrimdışı release web girişidir; üretim bootstrap/DB bağlantısı yoktur, kalite manifestinde tek dosya test fixture olarak kayıtlıdır. Playwright ile 320/375/402 genişliklerinde puan/ödül/auth ekranları kontrol edildi. Bekleme perdesi altındaki ve render tamamlanmadan çekilmiş ilk kareler reddedildi; yalnız doğrulanmış son kareler teslim kanıtıdır.

## Son kapı

`cd zankurd_mobile && ./tool/ci_yerel.sh --tam` çıkış kodu **0**:

- Format ve `dart analyze`: temiz; ayrıca Dart MCP hedef analizi `No errors`.
- Kalite: unknown=0, blockers/criticals/issues=0; taban izinde borç artışı yok.
- Ekran turu: 214 geçti.
- Tam test: 7.147 geçti, 3 atlandı, hata yok.
- Cihazsız uygulama akışları: 4 geçti.
- Son satır: `CI yerel: bütün adımlar geçti.`
- Native: 9 kare, integration test geçti. Son üretim koduyla tekrar derlendi.

Kalıcı kanıt: `/Users/kocer/Projects/zankurd_kapisma/t7/2026-10-30/`.
`ci_tam.log` son başarılı koşudur; `native/` dokuz kare ve kaynak SHA-256
manifestini, `web/` dört Playwright karesini, `reviews/` bağımsız model
incelemelerini içerir. Ana ajan kareleri ve kaynak farklarını ayrıca kontrol etti.

Eski test beklentileri yeni sözleşmeye uyarlandı; puan sözcüğü yerine anahtarlı
puan metni, katılış zamanı fixture'ı ve yeni auth metni doğrulanır. Sonuç kartı
başlıkları dokunmadan önce görünür alana kaydırılır ve hitTestable doğrulanır.
Fotoğraf kimliği testi avatarın göründüğü telefon düzeninde yayın öncesi ve
sonrasında aynı fotoğrafın korunduğunu sınar.
