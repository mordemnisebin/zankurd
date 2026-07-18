# ZanKurd — Kapsamlı Uygulama Denetimi (2026-07-18)

Bu rapor iki aşamalı hazırlandı: (1) bir keşif ajanı koda karşı otomatik
tarama yaptı, (2) her bulgu elle `grep`/dosya okuma ile doğrulandı —
ajanın hatalı bir tespiti (CLAUDE.md'nin yokluğu) bu doğrulamada
yakalanıp düzeltildi. Amaç ezbere/genel geçer önerilerden kaçınıp yalnız
dosya:satır kanıtı olan bulguları raporlamak.

## Bu oturumda ayrıca yapılan düzeltmeler

- Ana sayfa `_DailyLessonHero` taşma hatası kök nedenden giderildi
  (`MediaQuery` yerine `LayoutBuilder` — bkz. `home_screen.dart`).
- `play_hub_screen.dart`'ta oda-katılma sheet'inin `TextEditingController`'ı
  artık frame-sonrası dispose ediliyor (senkron dispose crash'i giderildi).
- Home'daki yarım bırakılmış `onOpenPlay` teaser'ı tamamlandı
  (`home/play_teaser_card.dart` — Pêşbazî sekmesine kısa geçiş kartı).
- Sonuç ekranında paylaş eylemi, gizli bir app-bar ikonundan ana eylem
  satırına taşındı (Pirs prensibi: paylaşımı öne çıkar); tekrarlayan
  app-bar kopyası kaldırıldı.
- `profile_screen.dart`'taki rozet paneli kapatma butonuna tooltip eklendi.
- 630 test yeşil, `dart analyze` temiz.

## 2026-07-18 ikinci tur: 7 ana ekranın gerçek render'ı alınıp incelendi

`quiz_screen`, `leaderboard_screen`, `profile_screen`, `settings_screen`,
`friends_screen`, `tournament_screen`, `contest_screen` ekran görüntüsü
yakalanıp incelendi (`test/support/widget_test_helpers.dart` ile). Hepsi
görsel olarak tutarlı ve mockup'lara sadık çıktı — `tournament_screen`'in
lobi görünümündeki büyük boş üst alan bilinçli bir `Center()` tasarımı
(bekleme ekranı, hata değil). Bu turda bulunan ve düzeltilen gerçek
sorunlar:

- **Renk tekrarı:** A/B/C/D şık renkleri (`quiz_widgets.dart`) ve soru
  öneri ekranındaki (`suggest_question_screen.dart`) aynı 4 renk **iki
  ayrı yerde, iki farklı hex seti olarak** tanımlıydı; ayrıca öneri
  ekranında aynı palet dosya içinde de iki kez kopyalanmıştı.
  `AppTheme.answerOptionColors` tek kaynağa taşındı, her iki ekran ona
  bağlandı.
- **Gerçek çeviri hatası ("Tu"/"Tu"):** Sonuç ekranının bot-yarışı
  karşılaştırma panelinde (`_RaceStandings`), oyuncunun kendi satırı
  Türkçe modda bile Kürtçe "Tu" (sen) etiketiyle gösteriliyordu.
  Kök neden: repository katmanı (`MockZanKurdRepository` +
  `SupabaseZanKurdRepository`) yerel oyuncu için sabit `'Tu'` adı
  üretiyor (bilinçli, veri katmanı i18n yapmamalı) — ama widget bu ham
  adı doğrudan gösteriyordu. Düzeltme: `_RaceStandings` artık kendi
  satırının adını her zaman `context.s('Tu','Sen')` ile ekranda
  yerelleştiriyor, gelen ham `Player.name`'i görmezden geliyor.
  (İlk denemede sadece kullanılmayan bir fallback dalını düzeltmiştim,
  gerçek render yolunu bulup asıl düzeltmeyi yaptım.)
- Diğer taranan hardcoded renkler (spin_wheel'in 8 dilim rengi, quiz
  cevap A/B/C/D paleti, kategori gradyanları) **incelendi ve meşru
  çıktı** — semantik token yerine ayrı bir "içerik paleti" olarak
  kalmaları doğru (bir renk çarkı veya kategori setinin `correct`/
  `wrong` gibi anlam taşıyan token'lara indirgenmesi yanlış olurdu).
- `TODO`/`FIXME` taraması temiz çıktı.
- Diğer `context.s('X','X')` (özdeş KU/TR) eşleşmesi ("Zor"/"Zor") kontrol
  edildi — bu meşru bir tesadüf (kelime iki dilde de aynı), hata değil.

Tüm testler (632) yeşil, `dart analyze` temiz.

## 2026-07-18 üçüncü tur: Pirs'in GERÇEK Play Store ekran görüntüleri indirilip incelendi

Önceki turlarda yalnız `ÖRNEK TASARIM/` klasöründeki (eski, muhtemelen
2026-07-16 civarı üretilmiş) mockup'lara bakmıştım. Bu turda tarayıcı
ekran görüntüsü aracı çalışmadığı için Play Store sayfasındaki gerçek
ekran görüntüleri `curl` ile doğrudan indirilip incelendi (7 görsel,
`kurdi.leyzok.pirs`). Gerçek uygulama mockup'lardan daha canlı/oyunsu bir
dil kullanıyor (turuncu-pembe illüstrasyonlu banner, çekmece menü, açık
tema quiz kartları). Karşılaştırma sonucu:

- **Alındı:** Sonuç ekranında gerçek 2×2 aksiyon grid'i doğrulandı (Tekrar
  Oyna / İncele / Paylaş / **Bizi Değerlendir**). Önceki turda "2×2 grid
  iddiası yanlıştı" demiştim — o değerlendirme YANLIŞ mockup'a (eski,
  yalnız 2 buton gösteren statik bir görsel) dayanıyordu; gerçek canlı
  uygulama ekranı 2×2 grid kullanıyor. `quiz_result_screen.dart`'a
  `in_app_review` paketiyle (zaten bağımlılıklarda vardı, `ReviewService`
  otomatik tetikleyicisinde kullanılıyordu) `InAppReview.instance
  .openStoreListing()` çağıran "Me binirxîne / Bizi değerlendir" butonu
  eklendi, satır düzeni Paylaş+Değerlendir olarak ikinci satıra taşındı.
  Bunu yaparken bir test regresyonu buldum ve kök nedenden düzelttim:
  `ListView(children:)` sliver tabanlı olduğu için ekran dışı widget'lar
  mount edilmiyor — `ensureVisible` mount edilmemiş bir widget'ı
  bulamıyordu, `scrollUntilVisible`'a çevrildi
  (`test/quiz_result_visual_test.dart`).
- **Alınmadı — kategori kartında coin bedeli:** Gerçek Pirs'te her
  kategori "Pirs. 100" gibi bir coin bedeli gösteriyor (kategoriye
  girmek ücretli). ZanKurd'da kategoriler ücretsiz, coin yalnız
  joker/kozmetik için harcanıyor — farklı bir ekonomi modeli, kopyalanacak
  bir "eksiklik" değil.
- **Alınmadı — açık tema + düz beyaz quiz kartları:** Gerçek Pirs'in quiz
  ekranı açık temalı, düz metin şıklı. ZanKurd'un koyu + TRT-tarzı renkli
  A/B/C/D şık kutuları zaten daha görsel olarak güçlü/ayırt edici —
  buradan geri adım atmak gerileme olurdu.
- **Alınmadı — çekmece (drawer) menü:** Gerçek Pirs yan çekmece
  kullanıyor; ZanKurd'un 5 sekmeli alt navigasyonu tek elle erişim
  açısından daha modern bir örüntü — değiştirilmedi.

Tüm testler (632) yeşil, `dart analyze` temiz.

## Yüksek öncelik

**1. Ölü ekran: `CommunityScreen` hiçbir yerde çağrılmıyor.**
`lib/src/screens/community_screen.dart` — `grep -rn "CommunityScreen" lib/`
yalnız kendi tanımını buluyor. Bu, Faz 9'da (`5e95002`) profil menüsünden
"Civak û Lîg" satırının bilinçli olarak kaldırılmasının bir kalıntısı —
ekranın kendisi hiç silinmemiş. `test/community_screen_test.dart` hâlâ
çalışıyor ve yeşil geçiyor ama artık erişilemeyen bir ekranı doğruluyor;
bu hem kod hem QA çabasının israfı. **Öneri:** ekranı ve testini silin,
ya da gerçekten geri getirilecekse (Rêz sekmesi + Hevalên Min'den ayrı bir
değer önerisi varsa) profile menüsüne yeniden bağlayın — ama "orada
duruyor, dokunmayalım" hâli sürdürülebilir değil.

**2. Test kapsamı — ReviewScreen'in (yanlış cevap incelemesi) hiç testi yok.**
`grep -rl "ReviewScreen(" test/` boş sonuç döndürüyor. Sonuç ekranından
"İncele" ve "Sadece yanlışlar" ile ulaşılan, kullanıcının hatalarından
öğrenmesini sağlayan bu ekran — SM-2 aralıklı tekrar sisteminin görünür
yüzü — hiç doğrulanmıyor. **Not (düzeltme):** ajan raporu "quiz_screen,
home_screen, leaderboard_screen, profile_screen, settings_screen,
sign_in/up_screen, room_screen" için de "test yok" dedi; bunu kendim
kontrol ettim ve YANLIŞ — bunların hepsi `test/widget_test.dart` içinde
(2296 satırlık tek dosyada) kapsamlı şekilde test ediliyor (`QuizScreen`
9, `SettingsScreen` 7, `LeaderboardScreen` 6, `ProfileScreen` 5,
`SignInScreen` 5, `RoomScreen` 4 kez örnekleniyor). Gerçek sorun "test
yok" değil, **tek dosyanın çok büyük olması** (aşağıya bkz.).

**3. iOS `PrivacyInfo.xcprivacy` hâlâ eksik.**
`find ios -iname "*.xcprivacy"` boş. Uygulama `shared_preferences`,
Firebase (Analytics/Crashlytics) kullanıyor — Apple'ın "required reason
API" listesine giren paketler bunlar arasında olabilir; dosya yoksa App
Store gönderiminde red riski var. Bu, 2026-07-15 audit'inde P1-9 olarak
işaretlenmiş ve hâlâ kapanmamış.

**4. GERİ ÇEKİLDİ (2026-07-18, görsel doğrulamadan sonra): "Görsel dil
ikiliği" iddiası yanlış çıktı.** İlk halde "`ScreenIdentityHeader` yalnız
9 ekranda, gradyan hero deseni 25 dosyada — hangisi doğru belirsiz"
deniyordu. Bu, yalnız `grep -rl "LinearGradient"` sonucuna dayanıyordu.
Kullanıcı onayıyla 5 aday ekranın (`level_screen`, `matchmaking_screen`,
`shop_screen`, `spin_wheel_screen`, `subcategory_screen`) gerçek ekran
görüntüsü alındı ve incelendi: her biri kendine özgü, amaca uygun bir
görsel merkez taşıyor — mağazanın öne çıkan ürün kartı (mockup-11),
çarkın altın bakiye kartı + renkli çark, seviye yolunun kategori-temalı
gradyanı. Bunları jenerik `ScreenIdentityHeader`'a çevirmek düzeltme
değil gerileme olurdu. `ScreenIdentityHeader`'ı kullanan 9 ekranın ortak
özelliği "düz liste/menü, özel görsel merkezi yok" — bu yüzden paylaşılan
bileşen mantıklı; diğerlerinin özel tasarımı da mantıklı. **Sonuç: gerçek
bir tutarsızlık yok, dokunulmadı.** (Bu süreçte ayrıca `shop_screen`'de
"27px taşma" sanılan bir bulgu da yanlış çıktı — kendi prob testimin
eski `setSurfaceSize` API'sini kullanmasından kaynaklanan bir test
artefaktıydı, doğru API ile temiz render oluyor.)

## Orta öncelik

**5. Hardcoded hex renk yoğunluğu belirli ekranlarda kümeleniyor.**
`spin_wheel_screen.dart` (15 adet), `quiz/quiz_widgets.dart` (10),
`suggest_question_screen.dart` (8), `home/daily_theme_card.dart` (7),
`leaderboard_screen.dart` (6), `home_screen.dart` (6) — `Color(0xFF...)`
doğrudan kullanımı, `AppTheme` token'ları yerine. Örnek:
`spin_wheel_screen.dart:734` `Color(0xFFC67A5C) // terracotta`. Palet bir
gün değişirse bu 6 dosya elle taranmalı; token'a taşınmadıkça her renk
güncellemesi kısmi kalma riski taşıyor.

**6. `test/widget_test.dart` 2296 satır — tek dosyada 60+ senaryo.**
Bu oturumda bu dosyada 6+ test bloğu düzenledim; her değişiklikte tüm
dosyayı (2296 satır) taramak zorunda kaldım. Ekran başına ayrı dosyaya
bölünmesi (örn. `home_screen_test.dart`, `settings_screen_test.dart`)
hem gezinmeyi hem gelecekteki bakımı kolaylaştırır — davranış zaten var,
sadece organizasyon borcu.

**7. Liderlik tablosunda "kendi sıran" satırı, mockup'taki gibi listenin
altına sabitlenmiş/vurgulu bir satır olarak değil, ayrı bir metin
banner'ı (`_LeagueBanner`, "Rêza te ya heftane: #5") olarak gösteriliyor.**
`leaderboard_screen.dart:241,259-329`. Mockup 9'da (`ÖRNEK TASARIM/...
(9).png`) kullanıcının satırı yeşille vurgulanıyor VE liste kaydırılsa
bile altta ikinci kez sabit gösteriliyor ("Pêşketina te heb e! 🔥" ile).
Şu anki banner de işlevsel olarak aynı bilgiyi taşıyor ama liste
içindeki konumunu görsel olarak vurgulamıyor — küçük ama gerçek bir
fark.

**8. Eski spec dosyasında doğrulanamayan bir iddia var: "sonuç ekranında
2×2 aksiyon grid'i."**
`docs/superpowers/specs/2026-07-12-bubblegum-arcade-redesign-design.md:50`
Pirs'ten alınacak ilke olarak "Sonuç ekranında 2×2 aksiyon buton grid'i"
yazıyor. Ama gerçek referans mockup'ı (`ÖRNEK TASARIM/...(8).png`) sadece
**iki** dikey buton gösteriyor (Dîsa biceribîne + Mala vegere), grid
değil. Bu satır muhtemelen yanlış hatırlanmış/karıştırılmış bir
referanstan yazılmış — ben de geçen turda bu spec'e güvenip aynı hatayı
tekrarlamak üzereydim, gerçek mockup'a bakınca fark ettim. **Öneri:**
mevcut spec dosyasındaki bu satırı düzeltin ya da "doğrulanmadı" notu
ekleyin — gelecekte başka bir oturum (ben dahil) aynı hataya düşebilir.

## Düşük öncelik / gözlem

**9. Text overflow koruması sistematik değil.** 80 `maxLines` + 20
dosyada `TextOverflow` kullanımı var ama 44 ekran dosyasının önemli bir
kısmında hiç yok — kesin liste çıkarılmadı, riskli ama kanıtlanmamış
alan olarak not düşülüyor.

**10. `AnimationController(` 19 kez `lib/src/screens/` genelinde
doğrudan görülüyor** — çoğu muhtemelen `initState`'te (doğru desen),
ama tek tek doğrulanmadı; `build()` içinde yeniden oluşturma riski
taşıyanlar ayrıca taranmalı.

## Ajan metodolojisi notu

Keşif ajanı "`CLAUDE.md` yok" dedi — bu YANLIŞ, dosya `zankurd_mobile/`
değil bir üst dizinde (`pirs kurmanci/CLAUDE.md`) duruyor; ajan yalnız
kendi çalışma dizinini taradığı için bulamadı. Bunu ben `ls` ile
doğrulayıp rapordan çıkardım. Diğer tüm bulgular (CommunityScreen,
xcprivacy, tooltip, test kapsamı, hardcoded renkler) elle doğrulandı ve
doğru çıktı.

## Önerilen sıradaki adımlar (öncelik sırasıyla) — DURUM

1. ✅ `CommunityScreen` + testini silindi.
2. ✅ `ReviewScreen` için `test/review_screen_test.dart` eklendi (3 test:
   boş durum, özet sayaçları, doğru/yanlış işaretleme + açıklama paneli).
3. ✅ `ios/Runner/PrivacyInfo.xcprivacy` oluşturuldu (UserDefaults +
   FileTimestamp kategorileri, standart reason code'larla). **Önemli
   sınırlama:** bu makine Windows, Xcode/macOS yok — dosyanın içeriği
   doğru ama Xcode projesine ("Copy Bundle Resources" build phase'ine)
   bağlanıp bağlanmadığı doğrulanamadı. İlk gerçek iOS build/archive
   sırasında bunun kontrol edilmesi gerekiyor.
4. ✅ Spec dosyasındaki yanlış "2×2 grid" referansı düzeltme notuyla
   işaretlendi.
5. ✅ `test/widget_test.dart` (2296 satır, 68 test) 7 ekran-temelli dosyaya
   bölündü (`auth_onboarding_test.dart`, `home_room_actions_test.dart`,
   `room_lobby_test.dart`, `quiz_flow_test.dart`,
   `leaderboard_result_profile_test.dart`, `settings_account_test.dart`,
   `home_room_failures_test.dart`) + ortak kurulum
   `test/support/widget_test_helpers.dart`'a taşındı. 68/68 test bloğu
   sayısal olarak doğrulandı (kayıp/çoğalma yok), tüm suite (632 test)
   geçiyor, `dart analyze` temiz.
6. ❌ **GERİ ÇEKİLDİ (2026-07-18).** Kullanıcı onayıyla 5 aday ekranın
   gerçek ekran görüntüsü alınıp incelendi — hepsi kendine özgü, amaca
   uygun görsel merkezler taşıyor (mağaza öne çıkan ürün kartı, çark
   bakiye kartı, seviye yolu teması). Bunları `ScreenIdentityHeader`'a
   çevirmek gerileme olurdu; gerçek bir tutarsızlık yoktu, madde 4'te
   detaylandırıldı. Dokunulmadı.

## Yapılmaması gerekenler

CLAUDE.md'nin "Design Spec Discipline" kuralı gereği, bu rapor **yeni
bir tam-uygulama redesign spec'i değildir** — mevcut onaylı mockup
hizalama planının (`2026-07-17-onayli-mockup-hizalama-plan.md`) üstüne
yamanacak nokta düzeltmeleri önerir. Yeni bir "hepsini baştan tasarla"
turu açmak, CLAUDE.md'de bizzat belgelenmiş 48 saatte 5 çakışan redesign
spec'i sorununu tekrarlar.
