# Metin-Yığını Panel Envanteri — Bulgular

**Tarih:** 2026-07-15 · Faz 2 envanteri, bkz.
[2026-07-15-karmasiklik-giderme-design.md](2026-07-15-karmasiklik-giderme-design.md)

## Bulgu Tablosu

| # | Widget | Dosya:satır | Mevcut sunum | Önerilen değişim (mevcut bileşen) |
|---|---|---|---|---|
| 1 | `_MasteryRow` (9 kategori satırı, `_MasterySection` içinde döngüyle çiziliyor) | `profile_screen.dart:1370-1461` (döngü: `1362-1363`) | Sabit 76px kategori adı metni + küçük rozet çipi + **bare `LinearProgressIndicator`** (satır 1440, 6px, kilim dokusu yok) + "3/20" küçük metin. 9 kategori üst üste — klasik metin-satırı yığını. | `LinearProgressIndicator` → projede zaten var olan `KilimProgressBar(value: progress, height: 6, color: badgeColor)` (`widgets/kilim_progress_bar.dart`) ile değiştirilir — dokulu dolgu, aynı API şekli (`value`), tek satır değişikliği. |
| 2 | Kategori performans çubukları (`_PedagogicalAnalyticsSection` içinde) | `profile_screen.dart:1622-1681` | Aynı desen tekrar ediyor: sabit 72px kategori adı + **bare `LinearProgressIndicator`** (satır 1654, `TweenAnimationBuilder` ile animasyonlu ama yine dokusuz) + sağda sayı. 9'a kadar kategori satırı. | Aynı öneri: `LinearProgressIndicator` → `KilimProgressBar`. `TweenAnimationBuilder` animasyon sarmalayıcısı korunabilir, yalnızca `builder` içindeki widget değişir. |
| 3 | `_AchievementUnlocks` (yeni rozet kutlaması) | `quiz_result_screen.dart:1356-1440` | **Tekrar bulunmadı / zaten iyi.** Altın gradyan panel + Roj ışını animasyonu (`_RojRaysPainter`) + her rozet ikon-rozeti + başlık/açıklama satırı olarak sunuluyor — metin yığını değil, referans alınabilecek bir örnek. | Değişiklik gerekmiyor. |
| 4 | Sonuç ekranı metrik satırı (doğru/yanlış/coin/XP) | `quiz_result_screen.dart` (hero kart bölümü, ekran görüntüsünde 4 renkli ikon dairesi + etiket olarak görünüyor) | **Tekrar bulunmadı / zaten iyi.** `result_after.png` ekran görüntüsünde 4 metrik, renkli ikon daireleri + kısa etiketlerle sunuluyor — düz metin satırı değil. | Değişiklik gerekmiyor. |

## Ekran Görüntüsü Çapraz Doğrulama

- `home_after.png`: Sol sütunda yoğun düz-metin satır yığını görünüyor — bu,
  koddaki Bulgu #1/#2'nin (profil/mastery bölümü ana sayfada da
  gösteriliyor olabilir) görsel kanıtı. Sağ üstteki mavi panel ve alttaki
  mor panel zaten kart/rozet diline sahip, iyi durumda.
- `profile_after.png`: Görüntü neredeyse tamamen koyu/boş yüklendi (yalnızca
  küçük bir mor döner yükleniyor ikonu görünüyor) — ekran görüntüsü render
  tamamlanmadan alınmış olabilir; kod incelemesiyle çelişmiyor ama görsel
  olarak doğrulayıcı değil. Bu dosyanın yeniden üretilmesi (Faz 2
  uygulamasından sonra) önerilir.
- `result_after.png`: Üst hero kart ve metrik satırı (Bulgu #4) iyi durumda;
  ortadaki altın panel (Bulgu #3, `_AchievementUnlocks`) da iyi durumda; en
  alttaki koyu panel zaten 2×2 aksiyon grid'i olarak uygulanmış (bubblegum
  arcade K3 kararı tamamlanmış görünüyor).

## Mevcut Görsel Dil Bileşenleri (referans)

- `KilimProgressBar(value, height=8, color=AppTheme.brandOrange)` —
  `widgets/kilim_progress_bar.dart`: pill şeklinde, dolgu içinde
  `KilimPatternPainter` dokusu olan ilerleme çubuğu. Bulgu #1/#2'nin
  doğrudan yerine geçebilecek hazır bileşen.
- `KilimPatternPainter(drawPattern, color, opacity)` —
  `widgets/kilim_pattern_painter.dart`: filigran doku çizen `CustomPainter`;
  `KilimProgressBar` bunu zaten dahili kullanıyor, ayrıca banner/header
  arka planlarında (`subcategory_screen.dart`, `home_screen.dart`) doğrudan
  da kullanılıyor.

## Sonraki Adım

Bu bulgular, ayrı bir takip planında ("Karmaşıklık Giderme — Faz 1/2 Uygulama")
somut kod değişikliklerine dönüştürülecek. Öncelik: #1 ve #2 aynı dosyada
(`profile_screen.dart`) aynı basit değişiklikle (bileşen değişimi, API
uyumlu) çözülebilir — düşük risk, yüksek görünürlük, tek PR'da birlikte
yapılabilir.
