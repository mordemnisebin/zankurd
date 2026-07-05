# Quiz Deneyimi Cilası ("TV Şovu Hissi") — Tasarım

**Tarih:** 2026-07-05
**Faz:** A / 4 (onaylı yol haritası: A cila → B avatar/unvan → C etkinlik/contest → D Learning Zone)
**İlham:** TRT Bil Bakalım'ın yarışma-programı sunumu; Pirs Kurmancî'nin akıcı quiz döngüsü.
**Durum:** Kullanıcı onayladı (2026-07-05, "onaylıyorum" + sonraki adımlar için otomatik pilot yetkisi).

## Amaç

Mevcut quiz ekranı işlevsel ama duygusal olarak düz: zamanlayıcı tekdüze,
doğru/yanlış anı sönük, seri yapmanın görsel bir karşılığı yok. Bu faz,
oyun kurallarına hiç dokunmadan (süre, puanlama, joker mantığı aynı kalır)
quiz döngüsünü gerilim–patlama–ödül ritmine oturtur. Diğer tüm modlar
(1v1, turnuva, günlük yarışma, gelecekteki contest) aynı ekranı kullandığı
için bu cila her moda birden yansır.

## Kapsam — 4 bileşen

### 1. Gerilim zamanlayıcısı
- Mevcut `_CircularTimer` (15 sn, `AnimationController` tabanlı) üç renk
  evresi kazanır: **sakin** (15–8 sn, mevcut accent), **uyarı** (8–5 sn,
  amber), **kritik** (son 5 sn, kırmızı).
- Kritik evrede: zamanlayıcı "kalp atışı" ölçek animasyonu yapar (saniyede
  bir hafif büyü–küçül) ve ekran kenarlarında hafif kırmızı vinyet belirir.
- Saniye tık haptiği mevcut `lightImpact` desenini korur.
- Renk evresi hesabı saf bir fonksiyona çıkarılır (test edilebilir):
  `TimerPhase phaseFor(double remainingFraction)`.

### 2. Cevap anı dramatizasyonu
- Şıkka basılınca ~400 ms **gerilim tutuşu**: seçilen şık nabız atar,
  sonuç bu kısa beklemeden sonra açıklanır. (Sonuç zaten `_explanationTimer`
  ile 800 ms gecikmeli açıklama gösteriyor; tutuş bu akışa eklemlenir,
  toplam bekleme kullanıcıyı yormayacak şekilde ayarlanır.)
- **Doğruysa:** doğru şıktan yukarı kısa konfeti patlaması (~20 parçacık,
  `CustomPainter`, paket yok) + şıkta scale-bounce.
- **Yanlışsa:** seçilen şık yatay sarsılır (shake, ~300 ms) + tam ekran çok
  kısa kırmızı flaş (opacity 0→0.15→0).

### 3. Seri (combo) rozeti
- Üst üste doğru cevaplarda başlık altında "×N Seri!" rozeti:
  - ×3–4: turuncu; ×5–9: mor + daha yoğun konfeti; ×10+: altın + mevcut
    `win.mp3` çalınır (yeni ses dosyası eklenmez).
- Seri kırılınca rozet kısa bir kırılma/solma animasyonuyla gider.
- Veri kaynağı mevcut `streak` değişkeni; yeni durum eklenmez. Eşik →
  görsel stil eşlemesi saf fonksiyon olarak yazılır (test edilebilir):
  `ComboTier? tierFor(int streak)`.

### 4. Puan uçuşu
- Doğru cevapta kazanılan puan ("+100" benzeri) doğru şıktan üstteki Puan
  çipine doğru uçar; çip varışta hafif zıplar (mevcut `AnimatedCounter`
  ile uyumlu).

## Teknik yaklaşım

- **Yeni bağımlılık yok.** Parçacıklar `CustomPainter`; sarsıntı/nabız/uçuş
  `AnimationController` + `AnimatedBuilder`.
- Tüm yeni görsel efektler **`lib/src/screens/quiz/quiz_effects.dart`**
  adlı yeni dosyada toplanır (`ConfettiBurst`, `ShakeWrapper`,
  `ComboBadge`, `ScoreFlyup`, `TimerPhase`/`ComboTier` saf mantığı).
  `quiz_screen.dart` yalnızca bunları kullanır — mevcut dosya daha fazla
  şişmez.
- Animasyonlar `isFlutterTestEnvironment` koruması ile testte anında
  tamamlanır (kodda yerleşik mevcut desen).
- Ses/haptik mevcut `SoundProvider` aç/kapa ayarına uyar; ayar kapalıyken
  görsel efektler çalışmaya devam eder.
- Web dahil tüm platformlarda çalışır; parçacık sayısı düşük tutulur
  (düşük donanım/web'de jank yaratmaz).

## Test planı

- Birim: `phaseFor` renk evresi eşikleri; `tierFor` combo eşikleri
  (2→null, 3→turuncu, 5→mor, 10→altın gibi sınır değerleri).
- Widget: doğru cevap sonrası `ConfettiBurst` ağaçta; yanlış cevap sonrası
  shake sarmalayıcının tetiklendiği; combo rozetinin ×3'te görünüp seri
  kırılınca kaybolduğu.
- Regresyon: mevcut 244 test geçmeye devam etmeli; `dart analyze` temiz.

## Kapsam dışı

- Yeni ses varlığı eklenmez (paket boyutu korunur), Lottie kullanılmaz.
- Süre/puanlama/joker kuralları değişmez.
- Sonuç ekranı bu fazda değişmez (Faz B'de avatar/unvanla birlikte ele
  alınacak).
