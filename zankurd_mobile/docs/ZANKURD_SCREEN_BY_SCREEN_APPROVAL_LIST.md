# ZanKurd Screen-by-Screen Approval List

Durum: Tum ekranlar onay bekliyor. Kod degisikligi yapilmadi.

| Ekran | Yeni gorsel yon | Aksan | Dokunulacak dosyalar | Logic riski | Uygulama zorlugu | Onay |
|---|---|---|---|---|---|---|
| Ana sayfa | Premium dashboard + ogrenme merkezi | Yesil-turkuaz + altin | `lib/src/screens/home_screen.dart`, `lib/src/screens/home/*` | Dusuk | Orta | Onay bekliyor |
| Quick play | 2x2 oyun modu vitrini | Mod bazli renkler | `lib/src/screens/home/quick_play_grid.dart` | Dusuk | Dusuk | Onay bekliyor |
| Kategori | Gorselli kategori galerisi | Kategori gradientleri | `lib/src/screens/categories_tab.dart`, `lib/src/screens/subcategory_screen.dart` | Dusuk | Orta | Onay bekliyor |
| Kategori kartlari | Gorsel + ikon + mastery rozeti | Kategoriye ozel | `lib/src/screens/categories_tab.dart`, `lib/src/config/category_visuals.dart` | Dusuk | Orta | Onay bekliyor |
| Quiz | Odakli soru paneli + net cevap state | Yesil-turkuaz | `lib/src/screens/quiz_screen.dart`, `lib/src/screens/quiz/quiz_widgets.dart` | Orta | Orta-Yuksek | Onay bekliyor |
| Quiz sonuc | Skor vitrini + odul ozeti | Altin + turkuaz | `lib/src/screens/quiz_result_screen.dart` | Dusuk-Orta | Orta | Onay bekliyor |
| 1vs1 matchmaking | Rekabet lobi karti | Turuncu-kirmizi | `lib/src/screens/matchmaking_screen.dart` | Dusuk-Orta | Orta | Onay bekliyor |
| 1vs1 bekleme | Radar + iki avatar VS | Turuncu-kirmizi + yesil success | `lib/src/screens/matchmaking_screen.dart` | Orta | Orta | Onay bekliyor |
| Oda kurma | Hero oda kodu + oyuncu hazirlik paneli | Mavi-mor | `lib/src/screens/home/hero_card.dart`, `lib/src/screens/home_screen.dart` | Orta | Orta | Onay bekliyor |
| Odaya kodla girme | Bottom sheet yerine net kod giris modalitesi | Mavi-mor | `lib/src/screens/home_screen.dart` | Orta | Orta | Onay bekliyor |
| Takim oyunu / oda | Oyuncu listesi + hazirlik durumu | Mavi-mor | `lib/src/screens/room_screen.dart`, `lib/src/screens/tournament_screen.dart` | Orta | Orta | Onay bekliyor |
| Liderlik | Podium + rank listesi | Altin/amber | `lib/src/screens/leaderboard_screen.dart` | Dusuk | Dusuk-Orta | Onay bekliyor |
| Pesbaz | Etkinlik karti + kisa leaderboard | Gorev aksani | `lib/src/screens/contest_screen.dart` | Dusuk-Orta | Orta | Onay bekliyor |
| Cark / gunluk odul | Odul sahnesi + cooldown chip | Altin + mor | `lib/src/screens/spin_wheel_screen.dart` | Dusuk-Orta | Orta | Onay bekliyor |
| Profil | Kisisel dashboard | Yesil + altin | `lib/src/screens/profile_screen.dart` | Dusuk-Orta | Orta-Yuksek | Onay bekliyor |
| Shop | Premium magaza listesi | Altin | `lib/src/screens/shop_screen.dart` | Dusuk | Dusuk-Orta | Onay bekliyor |
| Ayarlar | Gruplanmis kontrol paneli | Mor + turkuaz | `lib/src/screens/settings_screen.dart` | Dusuk-Orta | Orta | Onay bekliyor |
| Login/Register/Auth | Premium auth deneyimi | Turkuaz + mor + altin | `lib/src/screens/sign_in_screen.dart`, `lib/src/screens/sign_up_screen.dart` | Orta | Orta | Onay bekliyor |
| Dialog/modal/bottom sheet/input/buton | Tutarlilastirilmis sistem | Ekrana gore | `lib/src/widgets/*`, `lib/core/widgets/*`, ilgili screen dosyalari | Orta | Orta-Yuksek | Onay bekliyor |

## Ilk Dusuk Riskli Oneri

1. Liderlik ekrani: component yapisi ayrik, logic az, gorsel etki yuksek.
2. Shop ekrani: liste ve bakiye paneli net, CTA/touch target iyilestirmesi dusuk riskli.
3. Quick play / ana sayfa kartlari: kullanici ilk izlenimini guclendirir, logic dokunmadan gorsel iyilestirme mumkun.

## Once Gorsel Onay Gerektirenler

Quiz, 1vs1 bekleme, oda/room, auth ve profil ekranlari once mutlaka gorsel onay almalidir. Bu ekranlarda state, responsive yapi ve kullanici akisi daha yogun oldugu icin tasarim yonu netlesmeden uygulamaya gecilmemeli.
