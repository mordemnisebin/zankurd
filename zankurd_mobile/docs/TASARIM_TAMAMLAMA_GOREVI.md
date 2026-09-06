# ZanKurd — tasarımı tamamlama görevi

Bu depoda çalışacaksın. Sıra:

1. `docs/TASARIM_DEVAM_NOTU.md` — **yönü ve hazır bileşenleri anlatır.**
   Onu okumadan koda dokunma; yoksa var olan bileşeni yeniden yazarsın.
2. Kökteki `AGENTS.md` — bağlayıcı çalışma kuralları.
3. Bu dosya — kalan iş ve nasıl bitirileceği.

Hedef: **hiçbir ekran "dümdüz" kalmasın.** Uygulama App Store'da yayında,
o yüzden her adım küçük, test edilebilir ve geri alınabilir olmalı.

---

## 0. "TRT Bil Bakalım gibi olsun" ne demek, ne demek değil

Taklit değil. O tür uygulamalardan alınacak olan **görüntü değil, hangi
anların büyütüldüğü**:

| Yarışma programının yaptığı | ZanKurd'da karşılığı |
|---|---|
| Sahne karartılır, soru tek ışık altındadır | ✅ yapıldı (`AppTheme.stage`) |
| Skor sayarak çıkar, birden belirmez | ✅ yapıldı (`RollingCount`) |
| Kazanan podyuma çıkar, an kutlanır | ❌ podyum var ama kutlama yok |
| Sunucu vardır, tepki verir | ✅ Zana döngüde |
| Rakip görünür, fark hissedilir | ✅ halat çekme çubuğu |
| Ödül fiziksel gelir | kısmen — rozetler oturuyor, jeton uçmuyor |

**Studyo dekoru, sahte ışık huzmesi, parlayan 3B düğme YAPMA.** Bu
uygulamanın malzemesi kilimdir; büyütülecek anlar yarışma programından,
o anların **dili** kilimden gelir.

---

## 1. Doğrulanmış iki kusur — önce bunlar

### 1.1 Liderlik tablosunda büyük boşluk (`leaderboard_screen.dart`)

`docs/screenshots/tour/06_leaderboard.png` — sekme şeridi ile "Bronz Lig"
bandı arasında ~350 px boş alan var. Ekranın üçte biri hiçbir şey
söylemiyor. Podyum aşağı itilmiş ve ilk bakışta görünmüyor.

Boşluğun sebebini bul (büyük ihtimalle sabit `SizedBox` ya da `Spacer`),
podyumu yukarı al. Podyum bu ekranın kahramanıdır; kaydırmadan görünmeli.

### 1.2 Podyum kutlanmıyor (`leaderboard_screen.dart`)

Podyum var ama beyaz bir kartın içinde, hareketsiz duruyor. Bu uygulamanın
en "yarışma programı" anıdır ve bir belge gibi sunuluyor.

* Birinci basamak `KilimReveal` ile açılsın (sonuç ekranında zaten böyle).
* Sıra rozetleri `arena_kit.dart` içindeki **`RankMedal`** ile çizilsin.
  Bileşen zaten var ve liderlik LİSTESİNİN satırlarında kullanılıyor
  (`leaderboard_screen.dart:1547`), ama podyum kendi madalyalarını ayrıca
  çiziyor. Aynı ekranda iki ayrı madalya dili var; podyum da `RankMedal`
  kullansın.
* Puanlar `RollingCount` ile sayarak çıksın.
* Hareket azaltma açıkken üçü de sabit kalsın.

### 1.3 Profil beyaz kart yığını (`profile_screen.dart`)

`docs/screenshots/tour/07_profile.png` — üstteki yeşil kimlik kartı iyi;
altındaki her şey birbirinin aynı beyaz kutu. Ekran bir ayar listesi gibi
okunuyor, oysa oyuncunun kendini gördüğü yer burası.

* Seviye/lig göstergesi `RankMedal` kullansın — profil ekranında hiç
  kullanılmıyor, oysa liderlikte var ve iki ekran aynı sıralamayı
  gösteriyor.
* "Başarılar 0/13" satırı `MissionProgressCard` ile dokulu bir ilerleme
  taşısın.
* İstatistik sayıları `RollingCount` ile gelsin.
* Kartlar arasına kilim bordürü **serpme** — bir tane, kimlik kartının
  altında, ayırıcı olarak yeter. Her karta desen koyma; gürültü olur.

---

## 2. Kalan ekranlar — yöntem

Kalanları tahminle değil, **bakarak** bul:

```bash
flutter test tool/screenshots/screen_tour_test.dart
```

91 ekran görüntüsü `docs/screenshots/tour/` altına düşer (açık/karanlık,
Türkçe/Kurmancî, boş durumlar). Hepsine tek tek bak ve şu üç soruyu sor:

1. **Bu ekran ZanKurd'a mı ait, herhangi bir uygulamaya mı?** Hiçbir
   kimlik izi yoksa bir tane ekle — ama YALNIZ bir tane.
2. **Ekranın kahramanı belli mi?** Her şey aynı ağırlıktaysa hiçbiri
   önemli değildir. Ekranın işi neyse o büyük olsun.
3. **Ölü alan var mı?** Boş üçte bir, çözülmemiş bir yerleşimdir.

Şu ekranlar denetlenmedi, muhtemelen sade: `level_screen`, `story_screen`,
`review_screen`, `friends_screen`, `settings_screen`, `paywall_screen`,
`subcategory_screen`, `favorite_questions_screen`.

**`play_hub_screen`e DOKUNMA.** Kartları zaten baklava ikonu ve basamaklı
kilim deseni taşıyor; incelendi, gerek yok.

---

## 3. Ölçü: ne kadar kimlik yeterli

Ekran başına **bir** kimlik dokunuşu. İki tanesi çoğu zaman fazladır.

Sebebi şu: kilim motifi her yere konursa duvar kâğıdına döner ve hiçbir
şey söylemez. Şu an soru ekranında kilim tahtası ANLAM taşıyor (doğru/
yanlış kaydı); dekoratif kilim onun anlamını da sulandırır.

Kural: **motif ya bir bilgi taşısın ya da hiç olmasın.**

---

## 4. Kırmızı çizgiler — bu depoda YAŞANDI

1. **Var olmayan sabit uydurma.** `AppTheme.errorColor` ve `AppIcons.plus`
   YOKTUR; doğrusu `AppTheme.wrong`, `AppIcons.circlePlus`. Kullanmadan
   önce dosyada olduğunu doğrula.
2. **Private sınıf başka dosyadan kullanılamaz.** `_` ile başlayan widget'ı
   çağırma; ortak kullanılacaksa public dosyaya taşı.
3. **`flutter test` çalıştır.** Son teslim `dart analyze`dan geçmişti ama
   test koşulmamıştı: 7 px satır taşması ve teslim edenin kendi yazdığı
   bekçinin düşmesi sonradan bulundu.
4. **`Row` içinde her çocuk küçülebilmeli.** Sabit genişlikli rozet,
   `Expanded` metnin yanında bile satırı taşırır; rozeti de `Flexible` +
   üç nokta yap.
5. **`Theme` sarmalında `Builder` şart.** `build`in `context` parametresi
   sarmalın ÜSTÜNDEDİR ve eski temayı verir. Sahne temasında kart karardı
   ama sayfa krem kaldı — tam bu yüzden.
6. **Testte beklenen metni elle yazma.** `strings.dart`tan oku. Son
   teslimde '2. Oyuncu' diye tahmin edilmişti, öyle bir metin yok.
7. **Aynı şeyi iki kez söyleme.** Oda ekranında bekleyen slot "Henüz yok"u
   hem alt satırda hem rozette basıyordu; soru ekranında da "doğru cevap"
   kutusu karonun söylediğini tekrar ediyordu. İkisi de kaldırıldı.

---

## 5. Her adımdan sonra — atlanamaz

```bash
dart analyze                                    # temiz olmalı
flutter test                                    # 2367 test geçiyor
flutter test tool/screenshots/screen_tour_test.dart
```

Emoji ve `CustomPainter` metni test koşucusunda kutu çıkar; o ikisi
simülatörden doğrulanır, tur çıktısından değil.

**Görsel değişiklik simülatörden gözle doğrulanmadan bitmiş sayılmaz.**
Bu projede üç kusuru yalnız simülatör yakaladı: krem kalan sayfa zemini,
enine gerilmiş baklavalar, ayrık duran şerit. Üçü de "doğru ama yanlış
görünüyor" türündendi ve hiçbir test yakalayamazdı.

---

## 6. Bitti ölçütü — ekran başına

1. `dart analyze` temiz, `flutter test` tam geçiyor.
2. Ekran turunda açık VE karanlık temada taşma yok.
3. Değişikliğin yanında onu koruyan bir test var; testin belgesinde
   kusurun ne olduğu ve niçin sessiz kaldığı yazılı.
4. Commit gövdesi *neyin* değil *niçin* değiştiğini anlatıyor.
5. Simülatör ekran görüntüsünde kimlik görünüyor ve okunurluk bozulmamış.

Bir ekranı bitiremezsen **yarım olduğunu açıkça yaz.** Yarım iş kabul
edilir; tam sanılan yarım iş kabul edilmez.
