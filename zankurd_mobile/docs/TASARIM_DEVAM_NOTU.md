# ZanKurd — görsel kimlik: devam notu

Bu not, uygulamanın görsel yönünü sürdürecek ajan/IDE için yazıldı.
Araçtan bağımsızdır. **Önce bunu oku, sonra koda dokun.**

---

## 1. Yön nedir: kilim, oyun tahtasıdır

Uygulama bir yarışma programı taklidi DEĞİLDİR. TRT Bil Bakalım, Kahoot,
Duolingo, HQ Trivia gibi örneklerden alınan şey görüntü değil, **yoğunluğun
nereye harcandığı**: hepsi çekirdek döngüye harcar, kenar ekranlara değil.

ZanKurd'un kendi malzemesi kilimdir. Karar şudur:

> Tur ilerledikçe bir kilim şeridi dokunur. Her soru bir baklava; doğru
> cevap altın iplikle girer, yanlış cevap motifte bir gedik bırakır. Tur
> bitince elde paylaşılabilir bir nesne kalır.

Bu, Wordle'ın paylaşılabilir ızgarasının işlevini kilim diliyle yapar.
**Yeni bir görsel dil icat etme.** Var olanı yay.

### Palet ve kimlik (hazır, `lib/src/theme/app_theme.dart`)

| Rol | Sabit | Değer |
|---|---|---|
| Marka (Tîrêj) | `AppTheme.brand` | `#C2560E` |
| Marka koyu | `AppTheme.brandDeep` | `#A0450A` |
| Altın (ödül/iplik) | `AppTheme.gold` | `#D9A227` |
| Terracotta | `AppTheme.terracotta` | `#B86A3E` |
| Koyu zemin | `AppTheme.bg` | `#0E1512` |
| Açık zemin | `AppTheme.lightBg` | `#F7F4EE` |
| Sahne teması | `AppTheme.stage` | soru ekranı — tema ne olursa olsun koyu |

---

## 2. Hazır kimlik bileşenleri — YENİDEN YAZMA

| Bileşen | Dosya | Ne yapar |
|---|---|---|
| `KilimBoard` | `widgets/kilim_board.dart` | Turun dokuma kaydı. Altın dolu = doğru, içi boş = yanlış. |
| `KilimProgressBar` | `widgets/kilim_progress_bar.dart` | Dolgu üzerinde dokuma izi taşıyan çubuk. |
| `KilimReveal` | `widgets/kilim_reveal.dart` | Kutlamada merkezden açılan kilim dokusu. |
| `RojMascot` (Zana) | `widgets/roj_mascot.dart` | Güneşten türetilmiş maskot. 4 hâl: `happy`, `celebrate`, `thinking`, `sad`. Tamamen `CustomPaint`, asset yok. |
| `arena_kit.dart` | `widgets/arena_kit.dart` | `RewardToken`, `ArenaHero`, `ArenaStatusChip`, `MissionProgressCard`, `RankMedal`. |
| `RollingCount` | `widgets/rolling_count.dart` | Sayıyı hedefe doğru sayarak çıkarır. Hareket azaltmaya uyar. |

### Korunan iki karar — geri alma

1. **Doğru DOLU, yanlış İÇİ BOŞ** (kırmızı değil). Dokumada hata kırmızı
   iplik değil boşluktur; ayrıca dolu/boş bir *biçim* farkıdır ve renk
   körlüğünde, gri tonlamada, paylaşılan ekran görüntüsünde ayakta kalır.
   Bekçisi: `test/kilim_board_test.dart`.
2. **Zana yanlışta üzülür, azarlamaz.** Yanlış zaten cezalandırılıyor
   (seri kırılır, puan gelmez); maskotun da suçlaması bırakma sebebidir.

---

## 3. Bitmiş olan (dokunma, bozma)

* **Soru ekranı** — sahne (koyu), kilim tahtası şeridi, Zana ruh hâliyle,
  şık kutularına yükseklik tavanı (88 pt), "doğru cevap" kutusu kaldırıldı
  (karo zaten yeşile dönüp tik alıyor).
* **Sonuç ekranı** — turun kilimi, sayarak çıkan skor, ödül rozetleri
  skor sayımından sonra yerine oturur.
* **Ana ekran** — Zana selamlamada (seri varsa kutlar), günün görevi
  çubuğu kilim dilinde.
* **Paylaşım kartı** — turun kilimi basılıyor.
* **1v1 başlık** — halat çekme çubuğu (öndelik okunmadan görülür).
* **Yarış merkezi (`play_hub_screen`)** — BİLEREK dokunulmadı. Mod
  kartları zaten baklava ikonu ve basamaklı kilim deseni taşıyor;
  değişiklik için değişiklik yapılmasın.

---

## 4. Yapılacak — kimlik taşımayan ekranlar

Sırayla, en çok görülenden aza. Her madde ayrı bir commit olmalı.

### 4.1 `room_screen.dart` (1v1 lobi) — öncelik yüksek
Oda kodu ekranın kahramanı olmalı (Jackbox dersi). Şu an düz bir metin.
Kod büyütülsün, kopyalanabilirliği görsel olarak belli olsun, arkasına
sessiz bir kilim bordürü konsun. Bekleyen oyuncular `PlayerAvatar` ile
dizilsin; boş yer "bekleniyor" hâliyle görünsün ki oda dolmadığı
anlaşılsın.

### 4.2 `matchmaking_screen.dart` (rakip arama) — öncelik yüksek
Bekleme ekranı ölü zamandır ve şu an tamamen boş geçiyor. `RojMascot`
`thinking` hâlinde + `KilimProgressBar` belirsiz ilerleme dokusu.
**Hareket azaltma açıkken sabit kalmalı.**

### 4.3 `learning_screen.dart` (ders yolu) — öncelik orta
Yol düğümleri Duolingo'nun patikasını taklit etmesin; kilim motifi
zaten dizilim taşıyor — düğümler baklava olsun, tamamlananlar altın
dolsun. `KilimBoard`ın görsel dilini kullan ama `KilimBoard`ı zorlama:
o tur kaydı içindir, ders yolu için ayrı bir bileşen yaz.

### 4.4 `profile_screen.dart` — öncelik orta
Rozet ve istatistik kartları `arena_kit` bileşenleriyle
(`RankMedal`, `RewardToken`) birleştirilsin; şu an düz liste.

### 4.5 `shop_screen.dart` ve `spin_wheel_screen.dart` — öncelik düşük
Jeton gösterimi `RollingCount` kullansın. Çark zaten görsel bir öğe;
kilim paletiyle uyumlu hâle getirmek yeter, yeniden yazma.

---

## 5. Kırmızı çizgiler — geçen sefer TAM BURADAN kırıldı

Bu maddeler tahmin değil; aynı depoda yaşandı ve derleme kırdı.

1. **Var olmayan sabit uydurma.** `AppTheme.errorColor` ve `AppIcons.plus`
   YOKTUR. Doğrusu `AppTheme.wrong`, `AppIcons.circlePlus`. Bir sabiti
   kullanmadan önce dosyada olduğunu doğrula.
2. **Alt çizgiyle başlayan sınıf başka dosyadan kullanılamaz.**
   `_SingleAnimatedReactionBubble` gibi private bir widget'ı başka
   dosyaya çağırma; ortak kullanılacaksa public bir dosyaya taşı.
3. **Parantez kapatmayı bırakma.** Teslim edilen kod iki kez derlenmedi.
   `dart analyze` çalıştırmadan teslim etme.
4. **`Theme` sarmalında `Builder` şart.** `build`in `context` parametresi
   sarmalın ÜSTÜNDEDİR; onunla okunan tema değeri eski temayı verir.
   Sahne temasında tam bu yüzden kart karardı ama sayfa krem kaldı.
5. **Taşma.** `Row` içine uzun metin koyarken `Expanded`/`Flexible`
   kullan. Jeton/bakiye satırı 192 px taşmıştı.

---

## 6. Proje kuralları (AGENTS.md'den, bağlayıcı)

* **Türkçe** cevap ver.
* **Küçük, güvenli, test edilebilir adımlar.** Büyük refactor yapma.
* Kurmancî metinlerde **yalnız Hawar alfabesi**: `ı ğ ö ü İ` YOKTUR.
* Çeviri tek kaynaktan: `lib/src/l10n/strings.dart`. `context.s` ya da
  `.arb` kullanma.
* Dış bağlantılar `external_link.dart` üzerinden geçer.
* Singleton store'larda `resetInstance()` korunur (11 store var;
  `test/support/widget_test_helpers.dart` içinde hepsi sıfırlanır).
* **Yeni rapor dosyası üretme.** Bulgu üç yerde yaşar: testte, commit
  gövdesinde, kod yorumunda. Bu notun kendisi bir istisnadır — devir
  belgesidir, bulgu raporu değil.
* Her düzeltmenin yanına **onu koruyan bir test** yaz ve testin
  belgesine kusurun ne olduğunu, niçin sessiz kaldığını yaz.

---

## 7. Doğrulama döngüsü — her adımda

```
dart analyze                                   # temiz olmalı
flutter test                                   # 2364 test geçiyor
flutter test tool/screenshots/screen_tour_test.dart
```

Ekran turu bütün ana ekranları `docs/screenshots/tour/` altına basar:
açık/karanlık tema, Türkçe/Kurmancî, boş durumlar dâhil. **Emoji ve
`CustomPainter` metni test koşucusunda kutu çıkar** — o ikisi
simülatörden doğrulanır, tur çıktısından değil.

Görsel değişiklik simülatörden gözle doğrulanmadan bitmiş sayılmaz.
Bu oturumda üç kusuru yalnız simülatör yakaladı (krem kalan zemin,
enine gerilmiş baklavalar, ayrık duran şerit); hiçbir test yakalayamazdı
çünkü üçü de "doğru ama yanlış görünüyor" türündendi.

---

## 8. Kabul ölçütü

Bir ekran şu üçü sağlanınca bitmiştir:

1. `dart analyze` temiz, `flutter test` tam geçiyor.
2. Ekran turu çıktısında açık ve karanlık temada taşma yok.
3. Simülatör ekran görüntüsünde kimlik görünüyor ve okunurluk bozulmamış.
