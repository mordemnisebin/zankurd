# ZanKurd Screen Design Previews

Durum: Kod degisikligi yok. Bu rapor mevcut Flutter dosyalarindan okunan ekran yapisina gore hazirlandi.

## 1. Ana sayfa

Kaynak: `lib/src/screens/home_screen.dart`, `lib/src/screens/home/hero_card.dart`, `daily_missions_card.dart`, `quick_play_grid.dart`, `section_header.dart`.

1. Mevcut sorun: Ekran zaten hero kart, gunluk gorevler ve quick play grid kullaniyor; ancak premium dashboard hissi parca parca, header/hero/quick play arasinda tek bir ritim yok.
2. Neden cekici/profesyonel gorunmuyor?: Cok sayida parlak mod karti ayni anda dikkat cekiyor; ana aksiyon ile ikincil aksiyonlar arasindaki gorsel hiyerarsi daha net olabilir.
3. Onerilen yeni gorunum: Ustte sakin ZanKurd header, altinda tek guclu "bugun ne ogreneceksin?" hero; quick play modlari daha kompakt ama ikon/renkleri ayrismis.
4. Renk/ikon/kart/progress/gorsel zenginlik onerisi: Ana aksan yesil-turkuaz, coin/seri icin altin, quick play tile icinde 1vs1 bolt, cark casino, turnuva kupa ikonlari korunur.
5. Metin yogunlugunu nasil daha okunabilir yapacagiz?: Hero metni iki satiri gecmez; gorevler progress ring + tek satir hedefe iner; uzun Kurmanci alt metinler chip/meta alanina bolunur.
6. Dokunulacak dosyalar: `home_screen.dart`, `home_header.dart`, `hero_card.dart`, `daily_missions_card.dart`, `quick_play_grid.dart`.
7. Logic riski: Dusuk; layout ve gorsel katman agirlikli.
8. Uygulama zorlugu: Orta.
9. Onay durumu: Onay bekliyor.

## 2. Quick play / hizli basla alani

Kaynak: `lib/src/screens/home/quick_play_grid.dart`.

1. Mevcut sorun: 2x2 grid mevcut; baslik, alt metin ve ikonlar var ama kartlar oyun modu vitrini gibi daha guclu ayrisabilir.
2. Neden cekici/profesyonel gorunmuyor?: Her tile ayni agirlikta; "canli", "10 soru", "100 coin", "kupa" gibi degerler daha rozetli sunulabilir.
3. Onerilen yeni gorunum: Her tile icin mini mod rozeti, ikon arka plan halkasi ve alt satirda kisa fayda etiketi.
4. Renk/ikon/kart/progress/gorsel zenginlik onerisi: 1vs1 turuncu-kirmizi, gunun yarismasi altin, cark mor-altin, turnuva amber/kupa.
5. Metin yogunlugunu nasil daha okunabilir yapacagiz?: Tile basligi max 1-2 satir, alt bilgi chip formatinda; uzun "Pesbirka Roje" gibi metinlerde otomatik ellipsis.
6. Dokunulacak dosyalar: `quick_play_grid.dart`.
7. Logic riski: Dusuk.
8. Uygulama zorlugu: Dusuk.
9. Onay durumu: Onay bekliyor.

## 3. Kategori ekrani

Kaynak: `lib/src/screens/categories_tab.dart`, `lib/src/config/category_visuals.dart`.

1. Mevcut sorun: Kategori grid yapisi guclu; ancak ust baslik daha premium olabilir ve kategori kartlari arasinda bilgi hiyerarsisi daha netlesebilir.
2. Neden cekici/profesyonel gorunmuyor?: Kart gorselleri guclu olsa da meta "5 ast - pesbaz" her kartta ayni agirlikta kaliyor; mastery rozeti cok kucuk.
3. Onerilen yeni gorunum: Ustte akademik kategori vitrini, gridde gorsel odakli kartlar, her kartta ikon + mastery/progress rozeti.
4. Renk/ikon/kart/progress/gorsel zenginlik onerisi: Kategoriye ozel mevcut gradient/gorseller korunur; mastery icin altin mini badge, progress icin ince bar.
5. Metin yogunlugunu nasil daha okunabilir yapacagiz?: Kart icinde sadece kategori adi + tek meta satiri; uzun kategori adlari maxLines ve ellipsis.
6. Dokunulacak dosyalar: `categories_tab.dart`, gerekirse `category_visuals.dart`.
7. Logic riski: Dusuk.
8. Uygulama zorlugu: Orta.
9. Onay durumu: Onay bekliyor.

## 4. Kategori kartlari

Kaynak: `_CategoryCard` in `lib/src/screens/categories_tab.dart`.

1. Mevcut sorun: Gorsel, overlay, ikon ve mastery zaten var; fakat kart icindeki ikon, baslik ve rozet daha dengeli konumlanabilir.
2. Neden cekici/profesyonel gorunmuyor?: Bazi kartlarda gorsel/overlay agir basabilir; baslik ve rozet kucuk kalabilir.
3. Onerilen yeni gorunum: Gorsel arka plan korunur, alt kisimda yarim saydam bilgi bandi ve sag ustte daha okunur mastery badge.
4. Renk/ikon/kart/progress/gorsel zenginlik onerisi: Kategori gradient overlay, ikon glass chip, mastery altin mini badge.
5. Metin yogunlugunu nasil daha okunabilir yapacagiz?: Kartta aciklama yok; sadece ad, seviye sayisi ve progress.
6. Dokunulacak dosyalar: `categories_tab.dart`.
7. Logic riski: Dusuk.
8. Uygulama zorlugu: Orta.
9. Onay durumu: Onay bekliyor.

## 5. Quiz ekrani

Kaynak: `lib/src/screens/quiz_screen.dart`, `lib/src/screens/quiz/quiz_widgets.dart`.

1. Mevcut sorun: Score header, progress bar, soru paneli, cevaplar, wildcard ve alt CTA mevcut; fakat soru odagi daha guclu, cevap state'leri daha premium olabilir.
2. Neden cekici/profesyonel gorunmuyor?: Cevaplar ve kontrol alanlari islevsel ama metin agirlikli; timer, streak, coin ve jokerler ayni anda dikkat cekebilir.
3. Onerilen yeni gorunum: Ustte kompakt skor/progress, ortada tek sakin soru karti, altta daha genis cevap butonlari ve state rozetleri.
4. Renk/ikon/kart/progress/gorsel zenginlik onerisi: Ana aksan yesil-turkuaz; dogru yesil, yanlis kirmizi, suspense icin amber pulse; 50/50 joker icin ikon chip.
5. Metin yogunlugunu nasil daha okunabilir yapacagiz?: Soru metni kart icinde rahat satir araligi; cevaplar A/B/C/D marker ile ayrilir; aciklama kutusu cevap sonrasi ayri panel.
6. Dokunulacak dosyalar: `quiz_screen.dart`, `quiz/quiz_widgets.dart`, gerekirse `core/widgets/zankurd_quiz_option.dart`.
7. Logic riski: Orta; cevap state ve multiplayer bekleme/reveal akisi korunmali.
8. Uygulama zorlugu: Orta-Yuksek.
9. Onay durumu: Onay bekliyor.

## 6. Quiz sonuc ekrani

Kaynak: `lib/src/screens/quiz_result_screen.dart`.

1. Mevcut sorun: Skor header, accuracy chip, metric row, odul kartlari ve aksiyonlar var; ancak odul/istatistik bolumleri tekrarli ve kalabalik hissedebilir.
2. Neden cekici/profesyonel gorunmuyor?: 52px skor guclu ama altindaki coin/XP ve istatistikler daha derli toplu bir "sonuc ozeti" olarak gruplasan daha profesyonel olur.
3. Onerilen yeni gorunum: Tek sonuc hero, dort metric tile, odul kazanimi icin iki kisa reward card, en altta net CTA.
4. Renk/ikon/kart/progress/gorsel zenginlik onerisi: Basari durumuna gore yesil/altin, kayip/draw icin daha sakin ton; coin altin, XP turkuaz.
5. Metin yogunlugunu nasil daha okunabilir yapacagiz?: Uzun aciklamalar alt metin; ana sayilar buyuk, etiketler kisa.
6. Dokunulacak dosyalar: `quiz_result_screen.dart`, gerekirse `core/widgets/zankurd_metric_tile.dart`.
7. Logic riski: Dusuk-Orta; result navigation ve review butonu korunmali.
8. Uygulama zorlugu: Orta.
9. Onay durumu: Onay bekliyor.

## 7. 1vs1 matchmaking ekrani

Kaynak: `lib/src/screens/matchmaking_screen.dart`.

1. Mevcut sorun: Secim menusu, rastgele eslesme karti ve kategori chipleri var; rekabet hissi daha etkili olabilir.
2. Neden cekici/profesyonel gorunmuyor?: Ust tanitim karti sakin; 1vs1 modu daha enerjik bir "arena" gibi hissettirmeli.
3. Onerilen yeni gorunum: Arena hero karti, rastgele eslesme ana CTA, kategori chipleri ikinci seviye secim.
4. Renk/ikon/kart/progress/gorsel zenginlik onerisi: Sicak turuncu-kirmizi aksan, VS rozeti, shuffle ikonu, kategori chiplerinde secili state.
5. Metin yogunlugunu nasil daha okunabilir yapacagiz?: Hero aciklamasi tek cumle; kategori adlari chip olarak kalir.
6. Dokunulacak dosyalar: `matchmaking_screen.dart`.
7. Logic riski: Dusuk-Orta; eslesme baslatma eventleri korunmali.
8. Uygulama zorlugu: Orta.
9. Onay durumu: Onay bekliyor.

## 8. 1vs1 bekleme / eslesme ekrani

Kaynak: `_buildRadarSearch` in `lib/src/screens/matchmaking_screen.dart`.

1. Mevcut sorun: Radar daireleri, iki avatar ve VS zaten var; state gecisleri daha okunur olabilir.
2. Neden cekici/profesyonel gorunmuyor?: VS rengi ve radar aksani genel accent ile karisiyor; bulundu/bekliyor durumlari daha sinematik ayrisabilir.
3. Onerilen yeni gorunum: Ortada radar sahnesi, solda "Tu", sagda rakip slotu, altta status ve iptal butonu.
4. Renk/ikon/kart/progress/gorsel zenginlik onerisi: Arama turuncu pulse, bulundu yesil success, VS icin sicak gradient badge.
5. Metin yogunlugunu nasil daha okunabilir yapacagiz?: Tek status cumlesi + kucuk "lütfen bekleyin"; kategori bilgisi chipte.
6. Dokunulacak dosyalar: `matchmaking_screen.dart`.
7. Logic riski: Orta; animation ve found state korunmali.
8. Uygulama zorlugu: Orta.
9. Onay durumu: Onay bekliyor.

## 9. Oda kurma ekrani

Kaynak: `lib/src/screens/home/hero_card.dart`, `_createOnlineRoom` in `home_screen.dart`.

1. Mevcut sorun: Oda kurma ana sayfa hero kartindan tetikleniyor; ayri ekran degil, bu nedenle kullanici eylemi daha net vurgulanmali.
2. Neden cekici/profesyonel gorunmuyor?: Oda kur/katil/hizli pratik aksiyonlari ayni hero icinde yarisebilir.
3. Onerilen yeni gorunum: Hero icinde "Oda kur" birincil, "Kodla katil" ikincil, "Tek basina pratik" ucuncul aksiyon.
4. Renk/ikon/kart/progress/gorsel zenginlik onerisi: Mavi-mor oda aksani, grup ikonu, kod chip, canli oda badge.
5. Metin yogunlugunu nasil daha okunabilir yapacagiz?: Oda aciklamasi tek satir; buton etiketleri kisa.
6. Dokunulacak dosyalar: `home/hero_card.dart`, `home_screen.dart`.
7. Logic riski: Orta; oda olusturma async akisi korunmali.
8. Uygulama zorlugu: Orta.
9. Onay durumu: Onay bekliyor.

## 10. Odaya kodla girme ekrani

Kaynak: `_showJoinSheet` in `lib/src/screens/home_screen.dart`.

1. Mevcut sorun: Kodla katil bottom sheet olarak geliyor; raporda ayri preview verilmeli.
2. Neden cekici/profesyonel gorunmuyor?: Kod giris akisi kritik ama modal karakteri standart kalabilir.
3. Onerilen yeni gorunum: Koyu sheet, ustte anahtar/kod ikonu, buyuk input, "Tevli Bibe/Katil" CTA.
4. Renk/ikon/kart/progress/gorsel zenginlik onerisi: Mavi-mor border, kod icin monospace input hissi, clipboard/paste ikonu opsiyonel.
5. Metin yogunlugunu nasil daha okunabilir yapacagiz?: Sadece baslik, kisa yardim metni ve input.
6. Dokunulacak dosyalar: `home_screen.dart`, gerekirse `styled_input.dart`.
7. Logic riski: Orta; joinRoom ve snackbar davranisi korunmali.
8. Uygulama zorlugu: Orta.
9. Onay durumu: Onay bekliyor.

## 11. Takim oyunu / oda bekleme ekrani

Kaynak: `lib/src/screens/room_screen.dart`, turnuva icin `tournament_screen.dart`.

1. Mevcut sorun: Oda hero, oyuncular paneli, hazirim switch ve baslat butonu var; takim/oda atmosferi guclendirilebilir.
2. Neden cekici/profesyonel gorunmuyor?: Oyuncu listesi islevsel ama takim enerjisi ve hazirlik durumu daha gorsel olabilir.
3. Onerilen yeni gorunum: Ustte oda kodu hero, ortada oyuncu kartlari, altta hazirlik progress ve host CTA.
4. Renk/ikon/kart/progress/gorsel zenginlik onerisi: Mavi-mor gradient, oyuncu avatar halkalari, ready state icin yesil chip.
5. Metin yogunlugunu nasil daha okunabilir yapacagiz?: Oyuncu kartinda ad + durum + skor; uzun host bekleme metni daha kisa state banner.
6. Dokunulacak dosyalar: `room_screen.dart`.
7. Logic riski: Orta; ready/start ve live room state korunmali.
8. Uygulama zorlugu: Orta.
9. Onay durumu: Onay bekliyor.

## 12. Liderlik ekrani

Kaynak: `lib/src/screens/leaderboard_screen.dart`.

1. Mevcut sorun: Header, period tab, podium ve rank row yapisi var; podium premium ama genel aksan yesil/altin karisiyor.
2. Neden cekici/profesyonel gorunmuyor?: Liderlik icin madalya/rozet dili daha tutarli olabilir; rank rowlari daha yogun ama okunur hale getirilebilir.
3. Onerilen yeni gorunum: Altin odakli podium sahnesi, segment tablar, 4+ siralar icin kompakt list row.
4. Renk/ikon/kart/progress/gorsel zenginlik onerisi: Altin/amber podium, gumus/bronz ikinci ucuncu, refresh butonu sade icon card.
5. Metin yogunlugunu nasil daha okunabilir yapacagiz?: Rowlarda ad, rozet/seri ve skor tek hiyerarside; uzun adlar ellipsis.
6. Dokunulacak dosyalar: `leaderboard_screen.dart`.
7. Logic riski: Dusuk.
8. Uygulama zorlugu: Dusuk-Orta.
9. Onay durumu: Onay bekliyor.

## 13. Pesbaz ekrani

Kaynak: `lib/src/screens/contest_screen.dart`.

1. Mevcut sorun: Etkinlik tema karti, badge ve leaderboard var; ancak "gorev/progress" hissi zayif.
2. Neden cekici/profesyonel gorunmuyor?: Contest temasi ve leaderboard ayni gorsel agirlikta; ana etkinlik daha heyecanli sunulmali.
3. Onerilen yeni gorunum: Ustte gunun pesbaz karti, kategori/difficulty badge, basla CTA; altta kisa top 5.
4. Renk/ikon/kart/progress/gorsel zenginlik onerisi: Canli gorev aksani, trophy/flag ikonlari, sure veya seviye rozetleri.
5. Metin yogunlugunu nasil daha okunabilir yapacagiz?: Tema aciklamasi max 2 satir; leaderboard satirlari tek satir metadata.
6. Dokunulacak dosyalar: `contest_screen.dart`.
7. Logic riski: Dusuk-Orta.
8. Uygulama zorlugu: Orta.
9. Onay durumu: Onay bekliyor.

## 14. Cark / gunluk odul ekrani

Kaynak: `lib/src/screens/spin_wheel_screen.dart`.

1. Mevcut sorun: Cark, odul paneli, buton ve cooldown chip mevcut; odul sahnesi daha premium olabilir.
2. Neden cekici/profesyonel gorunmuyor?: Cark buyuk ama etrafindaki bilgilendirme sade; odul kazanimi daha guclu kutlanabilir.
3. Onerilen yeni gorunum: Cark merkezde, ustte kisa gunluk hak metni, altta odul/cooldown paneli ve tek CTA.
4. Renk/ikon/kart/progress/gorsel zenginlik onerisi: Altin + mor; ZK merkez rozeti, celebration icon, cooldown icin saat chip.
5. Metin yogunlugunu nasil daha okunabilir yapacagiz?: Uzun yardim metni en alta kucuk not; ana buton durumu tek kelime.
6. Dokunulacak dosyalar: `spin_wheel_screen.dart`.
7. Logic riski: Dusuk-Orta; spin animation ve odul verme akisi korunmali.
8. Uygulama zorlugu: Orta.
9. Onay durumu: Onay bekliyor.

## 15. Profil ekrani

Kaynak: `lib/src/screens/profile_screen.dart`.

1. Mevcut sorun: Avatar karti, dil toggle, stats, weekly chart, mastery, rozet koleksiyonu ve menu paneli var; bilgi yogunlugu yuksek.
2. Neden cekici/profesyonel gorunmuyor?: Cok fazla panel ayni sayfada; kisisel dashboard hissi var ama bolumler daha net gruplanmali.
3. Onerilen yeni gorunum: Ustte avatar + level/XP hero, altta sekmeli veya bolumlu dashboard: stats, basarilar, mastery, menu.
4. Renk/ikon/kart/progress/gorsel zenginlik onerisi: Yesil profil hero, altin XP bar, rozet grid, haftalik chart sade surface.
5. Metin yogunlugunu nasil daha okunabilir yapacagiz?: Uzun aciklamalar kaldirilir; stat tile ve chart kullanilir; menu satirlari icon + label.
6. Dokunulacak dosyalar: `profile_screen.dart`, rozet widgetlari gerekirse.
7. Logic riski: Dusuk-Orta; avatar edit, settings/shop/friends navigasyonlari korunmali.
8. Uygulama zorlugu: Orta-Yuksek.
9. Onay durumu: Onay bekliyor.

## 16. Shop / magaza ekrani

Kaynak: `lib/src/screens/shop_screen.dart`.

1. Mevcut sorun: Bakiye paneli ve item listesi net; satin alma butonu/tile hiyerarsisi daha premium olabilir.
2. Neden cekici/profesyonel gorunmuyor?: Liste satirlari islevsel; urunler vitrin hissi vermiyor.
3. Onerilen yeni gorunum: Ustte coin balance hero, itemlerde ikon, ad, kisa fayda, fiyat/sahip state CTA.
4. Renk/ikon/kart/progress/gorsel zenginlik onerisi: Altin premium aksan, satin al icin cart ikonu, sahip olunan icin check badge.
5. Metin yogunlugunu nasil daha okunabilir yapacagiz?: Urun aciklamasi max 2 satir; fiyat butonu sabit genislik.
6. Dokunulacak dosyalar: `shop_screen.dart`.
7. Logic riski: Dusuk; satin alma metodu korunmali.
8. Uygulama zorlugu: Dusuk-Orta.
9. Onay durumu: Onay bekliyor.

## 17. Ayarlar ekrani

Kaynak: `lib/src/screens/settings_screen.dart`.

1. Mevcut sorun: Hesap, gorunum, ses/bildirim ve hakkinda bolumleri var; uzun metinler ve expandable bolumler ekrani agirlastiriyor.
2. Neden cekici/profesyonel gorunmuyor?: Ayarlar listesi operasyonel ama bolum basliklari ve kontrol satirlari daha tutarli olabilirdi.
3. Onerilen yeni gorunum: Gruplanmis ayar kartlari, her satirda ikon + baslik + durum/degistirici, tehlikeli alan ayri warning panel.
4. Renk/ikon/kart/progress/gorsel zenginlik onerisi: Mor/gri kontrol aksani, delete icin kontrollu kirmizi, bildirim icin violet.
5. Metin yogunlugunu nasil daha okunabilir yapacagiz?: "Nasil oynanir" ve gizlilik metinleri accordion olarak kalir; ana listede kisa durum metni.
6. Dokunulacak dosyalar: `settings_screen.dart`.
7. Logic riski: Dusuk-Orta; name save, switches, delete dialogs korunmali.
8. Uygulama zorlugu: Orta.
9. Onay durumu: Onay bekliyor.

## 18. Login/register/auth ekranlari

Kaynak: `lib/src/screens/sign_in_screen.dart`, `lib/src/screens/sign_up_screen.dart`.

1. Mevcut sorun: Dark auth gradient, logo, language toggle, Google/guest/email form ve register stepper mevcut; zaten ayrica tasarlanmis ama biraz suslu.
2. Neden cekici/profesyonel gorunmuyor?: Glow/geometric sekiller fazla dikkat cekebilir; form alani daha sade ve guven veren hale gelebilir.
3. Onerilen yeni gorunum: Sol/ust logo + deger cumlesi, sag/alt sade auth karti, register icin 3 adimli net progress.
4. Renk/ikon/kart/progress/gorsel zenginlik onerisi: Turkuaz-mor ana CTA, altin kucuk vurgu, inputlarda net icon.
5. Metin yogunlugunu nasil daha okunabilir yapacagiz?: Auth basligi tek satir; alt metin tek cumle; form validation kisa.
6. Dokunulacak dosyalar: `sign_in_screen.dart`, `sign_up_screen.dart`, `styled_input.dart`, `styled_button.dart`.
7. Logic riski: Orta; auth provider, validation ve navigation korunmali.
8. Uygulama zorlugu: Orta.
9. Onay durumu: Onay bekliyor.

## 19. Dialog, modal, bottom sheet, input ve buton bilesenleri

Kaynak: `lib/src/widgets/error_dialog.dart`, `loading_overlay.dart`, `styled_input.dart`, `styled_button.dart`, `lib/core/widgets/zankurd_button.dart`, `zankurd_card.dart`.

1. Mevcut sorun: Ortak widgetlar var ancak ekranlar yer yer kendi buton/kart/input stillerini uretiyor.
2. Neden cekici/profesyonel gorunmuyor?: Button radius, padding, renk ve dialog hiyerarsisi ekrandan ekrana degisebiliyor.
3. Onerilen yeni gorunum: Filled/outlined/ghost buton sistemi, AppPanel/ZankurdCard yuzeyi, tek tip input ve modal standardi.
4. Renk/ikon/kart/progress/gorsel zenginlik onerisi: Ekran aksanina gore icon leading, net focus border, dialog warning/success state.
5. Metin yogunlugunu nasil daha okunabilir yapacagiz?: Dialogda baslik + kisa mesaj + iki eylem; bottom sheette tek konu.
6. Dokunulacak dosyalar: `lib/src/widgets/*`, `lib/core/widgets/*`, ilgili screen dosyalari.
7. Logic riski: Orta; ortak component degisimi genis etki yapar.
8. Uygulama zorlugu: Orta-Yuksek.
9. Onay durumu: Onay bekliyor.

## Preview Dosyalari

Detayli mockup/wireframe dosyalari `docs/design_previews/` altinda hazirlandi.

## Son Not

Bu ekran tasarim yonlerini onaylarsan, once sadece ana sayfa + kategori + quiz ekrani icin dusuk riskli gorsel iyilestirme paketini uygulayacagim.
