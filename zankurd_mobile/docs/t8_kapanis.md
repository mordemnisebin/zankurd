# T8 — Kurul 5 uzlaşı maddeleri

Kaynak: `/Users/kocer/Projects/zankurd_kapisma/kurul5/UZLASI5.md` ve tur5 kareleri.
T7 tabanı: `094ce7be`; başlangıç çalışma ağacı temizdi.
Canlı DB bağlantısı ve push yok; `.env*`/anahtar dosyaları okunmadı.

| Madde | Değişiklik | Bekçi |
|---|---|---|
| E1 | Hesap kaydet dialogu ve profil alt metni Apple, Google ve e-postayı kapsar. | `guest_google_link_test`: TR/KU metin, sosyal seçenekler, ≥14 pt. |
| E2 | Boş/geçersiz e-posta veya 6 karakterden kısa parolada Kaydet pasif; alan değişiminde anında güncellenir. | Aynı test: boş→eksik→geçerli→yeniden geçersiz; Apple/Google görünür. Playwright boş/geçerli form. |
| E3 | Tamamlanmış maçta göndermeyen “Oynamadı · hükmen”; süren maçta “Henüz oynamadı”; bilinmeyen eski RPC hakkında iddia yok. | `kurul5_turnuva_duello_test`, `turnuva_gonderim_test`, bracket presentation. |
| E4 | Sıfır puanlı tarafa ilk karede de dilim yok; pozitif küçük puanda %8 tabanı ve 0–0 nötr görünüm korunur. | `t8_game_ui_test`, `reward_feel_test`: iki yön, ilk/son kare ve 0–0. |
| E5 | Rakipsiz açık düello “Açık davet”; mevcut doğru sayısı kalıbı ve katılım olmazsa kapanma süresi. | `kurul5_turnuva_duello_test`, `async_duel_screens_test`, `friend_challenge_ui_test`: kodlu/kodsuz davet, devam et, paylaşım URL akışı. |
| E6 | Kaybetme/beraberlikte zafer ışın ve parıltısı kapalı, ana puan açık nötr; renkli sahne korunur. | `t8_game_ui_test`: win/loss hero, score rengi, painter rays ve scene mood; native iki sonuç. |
| E7 | Biten kupadaki CTA “Yeni turnuvaya katıl”. | `kurul5_turnuva_duello_test`; başlangıç katılım testleri korunur. |
| E8 | Final kaybedenine “İkinci oldun”; “Sen 245 – 510 QaAlı” ile puan sahipliği açık. | `kurul5_turnuva_duello_test`: tamamlanmış final ve rakip kazanan koşulu, ≥14 pt. |
| E9 | Çevrimiçi ayar açıklaması anlık durum, son görülme ve varsayılan kapalı tercihini birlikte anlatır. | `presence_controller_test`: TR/KU gerçek settings alt metni ≥14 pt; mevcut gizlilik/sunucu onayı testleri. |
| E10 | Yanıtlayıp rakibi beklerken sayaç ikincil renk; semantik “Rakibin süresi: N saniye kaldı”; geometri sabit. | `t8_game_ui_test`: gerçek yanıt→bekleme→broadcast; TR/KU renk/semantik/rect. |
| E11 | Durmuş sayaçta aynı genişlikte Lucide pause ve merkezi “Süre durdu” semantiği. | `t8_game_ui_test`, `tur3_bulgu_test`, `turnuva_sunucu_puani_istemci_test`; native reveal. |
| E12 | Yeni seçili ders kartı açılışta ensureVisible ile tamamıyla görünür; sonraki rebuild elle kaydırmayı geri çekmez. | `t8_learning_topic_visibility_test`: 320/375/402/800, TR/KU, ×1/×1.3, kart+Başla rect ve dokunulabilirlik. |
| E13 | Gerçek karo alt sınırından tam satır klibi; solma bandında yarım satır yok, scroll boyu ve son satıra erişim korunur. | Aynı test matrisi: ilk görünüm, son satır, alt panel ve dokunulabilirlik; Playwright ilk/son kare. |
| E14 | Oda puan şeridinde kendi adının yanında SelfMarkedName ile `(Sen)` / `(Tu)`. | `t8_game_ui_test`: TR/KU ×1/×1.3/×2, tek satır ve bilgi boyutu; native ×1.3. |

## Metin ve bağımsız inceleme

[TR/KU tablosu](t8_ku.md). Gemini 4 Argon üretim kod farkını ve ayrı
öğrenme/yerleşim farkını inceledi: ONAY. Gemini Flash + Argon KU son turda
uzlaştı; Grok kota nedeniyle yanıt veremedi. Bu istisna tabloda açıkça kayıtlı.

Soru bankası, sürüm, canlı veritabanı, kimlik servisi ve paylaşım gönderimi
değişmedi. E5'in kaldırdığı kullanılmayan `challengeLinkRow` anahtarı
çeviri bekçisi gereği temizlendi. Lucide üreticisinde önceden elle eklenmiş
ellipsis/snowflake/turtle eşlemeleri korundu; yalnız pause glifi eklendi.

## Görsel doğrulama

`tool/t8_web_preview.dart` ile gerçek üretim ekranları, bellek içi repo/auth/
presence üzerinden açılır; production bootstrap ve ağ oturumu kurulmaz.
`integration_test/t8_native_visual_test.dart` TR/KU oyun, sonuç, hesap,
ayar, ders, konu, davet, final ve hükmen senaryolarını gerçek iOS simülatörde
assert ederek yakalar. Kaydırma sonrası hitTestable doğrulanmadan hesap
dialogu karesi kabul edilmez.

Web'de Apple üretim davranışı gereği yoktur; native iOS hesabında Apple ve
Google birlikte doğrulanır. Preview konu anahtarları üretim kimlikleridir
(`Paradigma`, `Edebiyat`); ilk yanlış fixture kareleri teslim kanıtı sayılmaz.

## Son kapı

- Native iOS: 26 TR/KU kare; `01:31 +1: All tests passed!`, çıkış 0.
- Dart MCP hedef analizi: `No errors`.
- Release web önizlemesi derlendi; Playwright 320/375/402, TR/KU ve ×1.3
  görünümleri kontrol edildi. Son gezinmede tarayıcı hata sayısı 0.
- Odaklı sigma/kayma/tur grubu: 519 geçti.
- Tam CI: 7.202 test geçti, 3 test atlandı; 4 cihazsız uygulama akışı ve
  214/214 ekran turu geçti. Çıkış kodu 0.
- CI son satırı: `CI yerel: bütün adımlar geçti.`
- Tam kayıt: `/Users/kocer/Projects/zankurd_kapisma/t8/2026-10-30/ci_tam_final.log`.

İlk CI turunda altı eski beklenti yakalandı: açık davet başlığı, kullanılmayan
anahtar, iki hükmen etiketi, boş form doğrulaması ve ders kimliğini sayı sanan
T7 kaynak bekçisi. Üretim davranışına uygun beklentiler düzeltildi; sayı bekçisi
zayıflatılmadı, ders kimliği `(kategori, dersId)` kaydına çevrildi. Tüm odaklı
tekrarlar yeşil. İlk native girişte ekran dışına dokunan fixture reddedildi;
son koşuda görünürlük doğrulanıyor. Xcode'un paket çözümleme hatası pub açık
native koşuyla düzeldi; proje/mağaza ayarına müdahale edilmedi.

Kanıt klasörü: `/Users/kocer/Projects/zankurd_kapisma/t8/2026-10-30/`.
