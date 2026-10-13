# Sürüm notları — iç test

`play_console_submission_checklist.md` ve `play_store_internal_test.md`
bu dosyaya işaret ediyordu ama dosya yoktu (2026-07-27'de yazıldı). İki
kontrol listesi de "release notes alanına bu dosyanın içeriğini koy"
diyor; o alan boş bırakılamaz.

Buradaki metin **iç test** içindir: ne yaptığımızı ekibe anlatır. Mağaza
listesinde görünecek kullanıcıya dönük metin ayrı bir dosyadadır
(`store_listing.md`).

Yeni sürüm hazırlarken: en üste yeni bir başlık aç, eskiyi silme.

---

## 2.0.0 (21) — 2026-10-01

Marketing sürümü 1.9.2'den 2.0.0'a çıktı (1.9.2 (20) mağazaya gönderilmiş son
build'di; build numarası 21). Sebep: görünüm, içerik ve oyun modları öyle
değişti ki "küçük güncelleme" demek yanlış olurdu. Aşağıda "Oyuncunun göreceği"
yalnız kodda bugün açık olanı yazar; kapalı olan her şey en altta ayrıca
sayılır.

### Oyuncunun göreceği

- **Yeni görünüm (Şahnê tasarım sistemi).** Her ekran aynı bileşen
  ailesinden çiziliyor: sekmeler ve alt gezinme, soru ekranı, yarış akışları,
  hesap/ayarlar/mağaza/giriş/tanıtım. Yeni logo (pahlı soru balonu içinde Z)
  ve yeni uygulama simgesi. Her konunun kendi silüeti ve kilim bandı var
  (on bir konu).
- **On bir kategori:** Dil, Kültür, Tarih, Edebiyat, Coğrafya, Müzik,
  Sinema, Siyaset, Bilim ve Düşünce, Teknoloji, Dünya (Kurmancî: Ziman, Çand,
  Dîrok, Wêje, Erdnîgarî, Muzîk, Sînema, Siyaset, Zanist û Raman, Teknolojî,
  Cîhan). Her kategoride beş seviye. Paradigma iç kimlik olarak kalır; oyuncu
  "Bilim ve Düşünce / Zanist û Raman" görür. Dünya yeni: Kürtlerle doğrudan
  bağı olmayan nötr genel bilgi artık Kürt kategorilerine karışmayıp kendi
  adıyla duruyor.
- **2.486 oynanabilir soru.** Yaklaşık yüzde 70'i Kürt
  dili, tarihi ve kültürü; yaklaşık yüzde 30'u Dünya, Teknoloji ve Bilim ve
  Düşünce'de genel bilgi. Mağaza metni aşağı yuvarlanmış "2.400'den fazla"
  der.
- **Sırayla düello açık** (`kAsyncDuelEnabled = true`). Yarış sekmesinde
  "Sırayla düello" kartı: oyuncu sunucunun seçtiği soruları şimdi oynar, rakip
  kendi zamanında; sonuçlar "Düellolarım"da. Hızlı düelloda 20 saniyede
  rakip bulunamazsa teklif olarak çıkar.
- **Yarış sekmesi:** Hızlı düello (1v1 canlı), Sırayla düello, "Arkadaşlarınla"
  altında Oda kur / Kodla katıl (davet bağlantısı `zankurd.com/join/KOD`),
  Günün soruları. Liderlik tablosu: Gün / Hafta / Ay / Arkadaşlar; altına
  sabitlenen "benim sıram" satırı artık dönem puanından hesaplanır.
- **Öğren:** ders yolu, günlük hikâyeler, kelime kartları, Sözlük (Ferheng).
  Günün dersi 10 soru (ilk oturumda 5).
- Kurmancî arayüz metinlerinin tamamı ve soru bankası çok modelli denetimden
  geçti (aşağıda).
- Çevrimdışı tek kişilik oyun, reklamsız, isteğe bağlı abonelik ("ZanKurd
  Pro") aynen duruyor.

### Kapalı olanlar (oyuncu görmez)

- Turnuva: `kTournamentEnabled = false`; ekran kodda var, Yarış sekmesinde
  görünmez. Mağaza ve review metinleri turnuvadan söz etmez.
- Haftalık lig (`kWeeklyLeagueEnabled = false`).
- Gizli kategori yok: `hiddenCategoryIds` boş (Paradigma, Siyaset, Teknolojî
  2026-09-30'da yeniden açıldı).

### Kaputun altında

**İçerik genişlemesi ve doğrulama.**

- DeepSeek sorularından çok modelli doğrulamadan geçenler ayrı bir kopyada
  oynanır hâle geldi: 458 + 364 = 822 soru, üçüncü dalgada 31 soru daha
  (Kurmancî düzeltmeli). 151 doğrulanmış soruya kaynak yazıldı; kaynağı
  bulunamayan ya da cevabı yanlış çıkan 44 soru karantinaya döndü.
- Bilim ve Düşünce'ye kaynaklı 70 soru (bilim_0001–0070 aralığındaki yeniler);
  doğru şık konumları dengelendi (40'ın 38'i A'ydı).
- Dünya bilgisi olduğu için bir ara emekliye ayrılan 99 soru Dünya altında
  geri döndü; son olgu doğrulamasında iki modelin onayladığı 38 soru emekliye
  ayrıldı.
- Tek bir siyasi görüşü doğru cevap diye sunan sorular kategori yerine tek tek
  ayıklandı: 159 Paradigma/Siyaset sorusu + 17 yerel Siyaset sorusu istemcide
  emekli (`retired_question_ids.dart`); sunucuda 502 + 64 soru
  `is_approved = false` (silinmedi).
- Kurmancî: 687 arayüz metni ilk kez tam denetlendi (108 düzeltme), 1.316
  sorunun ilk tam Kurmancî denetimi yapıldı; uyuşmazlıkta üçüncü oy ChatGPT.
  Şablon izli soru metinleri doğallaştırıldı.
- Kalite kapısı ve sabitlenmiş sayılar (`test/playable_inventory_test.dart`)
  yeni bankalara göre yeniden kuruldu.

**Sunucu göçleri (hepsi canlıda, ayrıntı `supabase/applied.md`):**

- 2026-09-30: `xp_and_coin_idempotency`, `async_duels`, `async_duels_cron`,
  `hidden_categories_inactive` (kullanıcı terminalinden, tek işlemde; doğrulama
  `async_duels_verify` hepsi tamam). Sırayla düello bu göçlerle açıldı.
- 2026-09-30: `leaderboard_positive_scores`, `my_leaderboard_rank`,
  `sinema_category_and_questions` (+ `sinema_drunken_horses_fix`).
- 2026-09-30: `hidden_categories_reopen`, `contested_questions_unapprove`,
  `async_duel_all_categories`, `siyaset_second_pass_unapprove`,
  `cihan_and_science` (Dünya 399, Bilim ve Düşünce 132).
- 2026-10-01: `deepseek_verified_sync` (+539 soru; etkin kategorilerde onaylı
  4.179 → 4.718).
- Bu sürümde uygulanacak bekleyen göç yok. Sunucu 4.718 onaylı soru tutar;
  istemci 2.486'sını paketli taşır, çevrimiçi düello ve odalar sunucu
  bankasından çeker.

**Kod tarafı:** `pubspec.yaml` `2.0.0+21`; `docs/app_review_packet_2.0.0_build21.md`
bu build için yazıldı (eski 1.9.2 paketi tarihçe olarak duruyor);
`test/subscription_disclosure_test.dart` paket dosyasını artık sürüm başlığından
bulur (dosya adına gömülü 1.9.2 kalktı).

### Yayın öncesi kapılar

1. App Store Connect ve Play Console'daki en yüksek build numarasını kontrol
   et (21 hepsinin üstünde olmalı).
2. Mağaza ekran görüntüleri Şahnê öncesinden: yeniden alınmalı
   (`docs/store_listing.md` → "Mağaza ekran görüntüleri").
3. Mağaza metni: `docs/store_listing.md` (karakter sayıları sayılı). Kurmancî
   liste metninin anadil kontrolü.
4. App Review paketi: `docs/app_review_packet_2.0.0_build21.md`; App Privacy
   cevapları ikili ile karşılaştırılacak (veri envanteri değişmedi).
5. Fiziksel cihazda bir tur (YAYIN_ADIMLARI.md bölüm 6): bildirim simgesi,
   abonelik, bir tur oyun; ayrıca yeni logonun simge olarak doğru çıktığı.

---

## Sonraki sürüm — taslak (2026-09-27, sürüm numarası verilmedi)

> 2026-10-01: Bu taslak 2.0.0 (21) olarak yayına hazırlandı; güncel durum
> yukarıdaki bölümde. Aşağısı 2026-09-27 anının kaydıdır ("7 kategori" ve
> "sırayla düello kapalı" artık geçerli değil).

Dal: `tasarim/sade-ilk-deneyim` (uzakta `tasarim-sade-ilk-deneyim`). Yön:
arkadaşla oda + 1v1 yarışma (TRT Bil Bakalım modeli) VE öğrenme alanı; ilk
giren kaybolmasın. Sürüm numarası ve derleme yayın anında verilir.

### Oyuncunun göreceği

- Ana ekran: tek birincil eylem (günün dersi), ilk oturumda "3 adımda
  ZanKurd", iki kapı (Kurmancî öğren / Arkadaşınla yarış), konu ızgarası.
- Oda daveti: lobide "Arkadaşlarını davet et"; `zankurd.com/join/KOD`
  bağlantısı uygulama yüklüyse uygulamayı açar (iOS associated domains,
  Android App Links), değilse web'de odaya katar.
- Öğren ekranı yol + iki eyleme indi; şıkların arkasındaki kilim dokusu
  kalktı (okunurluk). Sıralama metni ne yapılacağını söylüyor.
- Kapsam: turnuva ve haftalık lig bayrakla kapalı; Paradigma, Siyaset,
  Teknolojî gizli; Kürtlerle bağı olmayan 121 dünya bilgisi sorusu oyundan
  çıktı (oynanabilir: 1.250 soru, 7 kategori).
- Arkadaşlık isteği bildirimine dokunmak Arkadaşlar ekranını açar.
- Sırayla düello (oyun, sonuç, Düellolarım; eşleşmede rakip yoksa teklif):
  HAZIR ama `kAsyncDuelEnabled` ile KAPALI — sunucu göçü bekliyor.

### Yayın öncesi kapılar (sırayla)

1. Sunucu göçleri (hesap sahibi onayıyla, `supabase/applied.md`; üçü de
   2026-09-27'de yerel Supabase'de uçtan uca doğrulandı):
   `2026-09-28_hidden_categories_inactive.sql` (tek `update`);
   düelloyu açmadan önce `2026-09-28_async_duels.sql` +
   `2026-09-28_async_duels_cron.sql`. Sonra `kAsyncDuelEnabled = true`.
   Ayrıca bekleyen `2026-09-22_xp_and_coin_idempotency.sql` (solo XP ve
   coin harcamasında çift yazımı önler; istemci onsuz da çalışır).
2. Web: `./release_web.sh`; `docs/HOSTINGER_DEPLOY_CHECKLIST.md` →
   "Uygulama bağlantıları" doğrulaması (`.well-known` JSON dönmeli).
3. Apple: `com.zankurd.app` için Associated Domains yeteneği; profil
   yenilenir.
4. Play: Play App Signing SHA-256'sı `web/.well-known/assetlinks.json`a
   eklenir (yalnız yükleme anahtarı var).
5. Bildirim gönderimi `tool/send_push_outbox.py`nin bu sürümüyle
   (`data.kind` taşır).
6. Mağaza metni: `docs/store_listing.md`.
7. Kurmancî taslakların anadil kontrolü: `home.*`, `room.invite.*`,
   `duel.async.*` anahtarları ve düello bildirimi metni.

### Doğrulama (2026-09-27, yerel)

`dart analyze` temiz; `flutter test` 3132 test geçti (5 atlandı); ekran
turu 97/97; cihazsız akışlar 4/4; soru kalitesi kapısı ve dokunma hedefi
taraması temiz. CI'da Android işi atılacak anahtarla imzalanacak biçimde
düzeltildi (2026-08-09'dan beri anahtar yokluğundan kırmızıydı).

---

## 1.9.2+20 — 2026-09-10

Bu paket yayın öncesi doğrulama ve release-hygiene turudur. Son yerel doğrulama
setinde `flutter analyze` temiz geçti; release/checklist/migration sözleşmeleri
32/32, tam Flutter paketi 2740/2740 test ile `All tests passed!` sonucunu verdi.
91 ekran/varyantlık görsel tur da eksiksiz geçti.

### Son regresyon düzeltmeleri

- Hesap değişiminde cihazdaki yerel rozetler artık önceki kullanıcıdan yeni
  kullanıcıya taşınmıyor.
- Günlük görev deposu gün değişimini singleton sıfırlaması gerektirmeden
  algılıyor; dünkü görev/sayaç durumu yeni güne yazılamıyor.
- Seviye belirleme ekranında hızlı çift dokunuşun aynı cevabı iki kez
  işlemesi ve soru atlatması engellendi.
- “Hareketi azalt” tercihi doğru cevap geri bildirimi ile ana ekran giriş
  animasyonunda da uygulanıyor.
- Sosyal OAuth tarayıcı açılışı gerçek oturum oluşmadan başarılı giriş
  analitiği sayılmıyor; mağazada kozmetik kuşanma kaydı başarısızsa satın alma
  başarı kutlaması gösterilmiyor ve retry ikinci kez jeton harcamıyor.
- Alt kategori hero görseli dekoratif semantics düğümü olmaktan çıkarıldı.
- Öğrenme ekranındaki “Flaş kart” eylemi artık normal ders görünümüne değil,
  doğrudan kart kipine açılıyor; “Dersler” normal ders kipinde kalıyor.
- “Soru çöz” akışı boş soru havuzunda veya yükleme hatasında sessizce
  kapanmak yerine yerelleştirilmiş uyarı ve “Tekrar” eylemi gösteriyor.
- Çevrimiçi turdaki sunucu UUID'li sorular sonuç ekranına kaynak soru olarak
  taşınıyor; yerel bankada bulunmasalar bile Yanlışlar → Tekrar akışı çalışıyor.
- Playwright smoke turu offline ve sosyal-backend modlarını açıkça ayırıyor;
  offline turda kilitli hızlı düelloyu tıklamaya çalışmıyor.

### Derleme doğrulaması

- Production istemci yapılandırması değerleri yazdırılmadan web ve mobil için
  doğrulandı; production web release derlemesi `build/web` altında üretildi.
- Android release AAB başarıyla üretildi; `jarsigner` sonucu `jar verified`,
  `bundletool validate` temiz. Manifestte `com.zankurd.app`, versionCode `20`
  ve versionName `1.9.2` doğrulandı.
- iPhoneOS Release, `--no-codesign` ile başarıyla derlendi. Üretilen
  `Runner.app` içinde bundle id `com.zankurd.app`, sürüm `1.9.2`, build `20`
  doğrulandı; bu tur gerçek App Store imzası/IPA yüklemesi yapmadı.
- Production backend'e yazma riski yaratmamak için tarayıcı etkileşim smoke'u
  ayrı, Supabase yapılandırması olmayan güvenli yerel build üzerinde yapıldı.
  Ana Playwright smoke geçti; learning-focus turu 10 ekran görüntüsüyle
  `errors: []` verdi.

### Yayın güvenliği

- Production şemasına veya uygulama verisine SQL yeniden uygulanmadı. Yalnız
  migration-history metadata'sındaki doğrulanmış fark, hesap sahibi onayıyla
  `supabase migration repair --status applied 20260819000000` kullanılarak
  eşitlendi; ardından `supabase migration list --linked` ile local/remote
  geçmişin eşleştiği doğrulandı.
- `20260819000000_gamification_and_custom_rooms.sql` yeniden çalıştırılmadı.
  History farkı tekrar görülürse doğrudan `supabase db push` yapılmamalı;
  önce aynı kontrollü history doğrulama/repair prosedürü yeniden değerlendirilmeli.
- Playwright onboarding smoke turundaki yaş onayı Flutter web semantiğinde
  `.check()` yerine `.click()` sonrası `aria-checked=true` beklenerek
  doğrulanıyor; bu davranış release tooling kontratıyla korunuyor.
- Güvenli offline smoke sosyal backend beklemiyor. Staging/preview turunda
  gerçek matchmaking doğrulaması yalnız staging yapılandırmasıyla ve
  `ZANKURD_EXPECT_SOCIAL=1` ile etkinleştirilmeli; production yapılandırması
  yerel otomatik smoke için kullanılmamalı.

### Bilinen bloklayıcı olmayan araç zinciri borçları

- `flutter_tts 4.2.5` web WASM dry-run'da JS interop uyumluluk uyarıları
  üretiyor; mevcut JavaScript web release derlemesi başarıyla tamamlanıyor.
- Bazı Android eklentileri Built-in Kotlin geçişi, `flutter_tts` ise iOS Swift
  Package Manager desteği için gelecek Flutter sürümlerine dönük uyarı veriyor.
  Flutter 3.44.7 ile mevcut Android/iOS release derlemelerini engellemiyorlar.
- `cached_network_image` için 4.x major sürümü mevcut; bu release-hygiene
  turuna ilişkisiz API değişikliği taşımamak için yükseltme ayrı tutuldu.

### Bu sürümde kalan manuel kapılar

- Staging/preview istemci yapılandırmasının sağlanması ve iki istemcili sosyal
  akışın staging backend üzerinde doğrulanması.
- App Store Connect / Play Console üzerindeki gerçek en yüksek build ve sürüm
  numarasının gönderimden önce kontrol edilmesi.
- Fiziksel cihazda gerçek mağaza, satın alma/restore ve iki yönlü production
  multiplayer smoke turu; App Store için gerçek imzalı IPA/arşiv doğrulaması.
- Hosting deploy kimlik bilgilerinin (`.env.deploy`) sağlanması ve gerçek
  deploy'un ayrıca yürütülmesi.

---

## 1.9.1+13 — 2026-07-27

Bu tur bir denetim turudur: yeni özellik yok, 112 düzeltme var. Ağırlık
okunabilirlik ve içerik doğruluğunda.

### Okunabilirlik (17 düzeltme)

Bütün ekranlarda metin/zemin kontrastı ölçüldü ve WCAG AA eşiğinin
(4.5:1) altında kalan her yer düzeltildi. En ciddileri:

- Açık temada **bütün** sönük metinler 3.54:1'di — tek bir renk sabiti
  ekranların yarısını etkiliyordu.
- Podyum sıra numaraları 1.36:1; okunabilirliğini yalnız altındaki
  gölgeye borçluydu.
- Turnuvanın ne zaman başlayacağını söyleyen satır 1.78:1.
- Soru öner ekranında B, C, D harfleri karoda kayboluyordu (1.93:1).

Renk kararları artık ölçüte bağlı: `onAccentTint` ve `onSolid`
yardımcıları zemini hesaplayıp yazı rengini seçiyor, kontrast zaten
yeterliyse rengi değiştirmiyor.

### İçerik (16 düzeltme)

- **Aynı soru bankada üç kez duruyordu.** 479 soru anlamsız bir ders
  çerçevesi cümlesiyle başlıyordu; o cümle silinince 240 grubun 239'unun
  üçlü kopya olduğu görüldü. Kopyalar atıldı: 2387 → 1908 soru, gerçek
  içerik azalmadan.
- Doğru cevabın biçimle ele verdiği sorular kapatıldı (en uzun
  çeldiricinin 1,5 katından uzun doğru cevap: sıfır).
- Sorunun istediği türden olmayan şıklar düzeltildi ("hangi dilde?"
  sorusuna kitap adı, "hangi şehir?" sorusuna siyasi parti).

### Dil (10 düzeltme)

- Türkçe başlıklarda büyük İ noktasını kaybediyordu ("GÜVENLIK").
- Türkçe günlük görev kategoriyi Kurmancî yazıyordu ("Muzîk", "Dîrok").
- Kurmancî metinlere Türkçe kelime ve harf sızmıştı; iki soruda Kurmancî
  açıklama Türkçenin birebir kopyasıydı.
- Yüzde biçimi üç yerde Kurmancîde Türkçe önekle yazılıyordu.

### Veri

- Yeni oyuncuya sıralamada "1. sıradasın, 5000 puanın var" deniyordu:
  çevrimdışı depo demo tablosunun birincisini "senin satırın" diye
  döndürüyordu.

### Marka

- Uygulama simgesi ürünün logosu değildi; simge, açılış ekranı ve
  uygulama içi logo tek kaynaktan yeniden üretildi.
- Android'e uyarlanabilir simge eklendi (`monochrome` katmanı dahil).

### Test

987 test geçiyor. Her düzeltmenin yanında onu koruyan bir bekçi var;
bekçilerin çoğu ölçüt tabanlı (kontrast oranı, alfabe, kopya gövde), yani
yarın eklenecek içerikte de çalışır.

### Bu sürümde olmayan

- Fotoğraf kapsamı %9,9'da duruyor (lisans kararı bekliyor).
- İki şıklı sorularda soru kartı ekranı tam doldurmuyor; dolgu bir kademe
  açıldı ama kartın kalan alana uzaması ayrı bir iş.
