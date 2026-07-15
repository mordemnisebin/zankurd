# ZanKurd Bubblegum Arcade Yeniden Tasarımı

**Tarih:** 2026-07-12
**Durum:** Palet, kültürel taşıyıcı ve yerleşim kararları uygulandı (`da28ce1`, `c5e9e90`, `43891e0`, `e0dcc2c`, `ce91c1a`). **Not (2026-07-15):** Bu dokümanın "Light/Dark Öncelik Değişikliği" bölümündeki açık-öncelikli karar `fc6d2dd` ile geri alındı — bkz. o bölümdeki güncelleme notu. Palet/bileşen kararları geçerliliğini korur.
**Süpersede eder:** [2026-07-10-pirs-inspired-full-app-redesign-design.md](2026-07-10-pirs-inspired-full-app-redesign-design.md) (turuncu marka rengi bırakıldı).

## Amaç

ZanKurd'u, Pirs - Pêşbirka Kurdî ve Dribbble'daki en güçlü quiz/trivia app
örneklerinin taşıdığı "neşeli ve oyunsu" (Duolingo/Kahoot tarzı) enerjiye taşımak —
hem renk sistemi hem de ekran yerleşim mantığı (bilgi mimarisi) üzerinden. Turuncu
ve mor tamamen bırakılır; yeni, bağımsız bir palet kurulur.

Başarı ölçütü: Tüm ekranlarda tutarlı, canlı, tek bakışta "oyun" hissi veren;
Kurmancî kimliğini renk yerine mascot üzerinden taşıyan; mevcut 5 sekmeli
navigasyonu ve tüm iş mantığını (skor, coin, XP, joker, matchmaking) değiştirmeyen
bir görsel sistem.

## Mevcut Durum ve Korunacaklar

`AppTheme` (`lib/src/theme/app_theme.dart`) zaten iyi kurulmuş bir token mimarisi
sunuyor: adlandırılmış renk sabitleri (`brandOrange`, `playGreen`, `playPink`,
`playCyan`, `playPurple`), light/dark palet ayrımı, tema-farkında yardımcı
metodlar (`surfaceColor(context)`, `backgroundGradient(context)`,
`cardDecoration()`). Bu redesign bu mimariyi **değiştirmez**, yalnızca token
değerlerini yeni palete göre günceller.

Korunacak sözleşmeler (2026-07-10 spec'inden miras):

- Navigation, route ve event handler davranışı — **5 sekmeli alt bar korunur**
  (hamburger menüye geçilmez; ZanKurd'un 4 eşit-önemli bölümü — Fêr Bibe/Bilîze/
  Civak/Profîl — için alt bar hamburger'dan daha erişilebilir).
- Quiz skoru, zamanlama, joker, coin ve XP hesapları.
- Oda, matchmaking, 1vs1, takım, turnuva ve contest akışları.
- Provider, repository, service, Supabase, auth ve veritabanı sözleşmeleri.
- Kurmancî/Türkçe dil seçimi ve tüm mevcut test key'leri.
- Rubik başlık fontu (yeni font eklenmez).
- Zana/`RojMascot` (`lib/src/widgets/roj_mascot.dart`) — tamamen `CustomPaint` ile
  çizilen, "kilim dilinde 12 üçgen ışın" motifine sahip güneş karakteri. Geometri
  korunur, yalnızca ışın rengi güncellenir (bkz. Kültürel Taşıyıcı).

## Referans Kullanım Sınırı

Pirs'ten (`kurdi.leyzok.pirs`) alınacak ilkeler — **renk değil, yalnızca yerleşim
mantığı**:

- Tam-genişlik, tek-eylem mod kartları (küçük 2×2 ikon grid yerine).
- Kategori seçimi: ayrı, sade bir tam-ekran liste (renkli daire ikon + isim +
  bedel rozeti), gömülü sekme/grid değil.
- Sonuç ekranında 2×2 aksiyon buton grid'i (Dîsa Bilîze / Berdewam Bibe / Parve
  Bike / Me Binirxîne).
- Üst bar: coin bakiyesi + avatar, karşılama altında büyük, vurgulu Zana kartı.

Birebir alınmayacaklar: Pirs'in mor rengi, logosu, illüstrasyonları, metinleri,
hamburger navigasyonu.

## Renk Sistemi — "Bubblegum Arcade"

Turuncu/mordan bağımsız, Kahoot tarzı saf oyun enerjisi taşıyan aile:

| Rol | Hex | Kullanım |
|---|---|---|
| Ana (indigo) | `#6C5CE7` | Birincil aksiyon, navigasyon aktif durumu, marka |
| İkincil (pembe) | `#FF3B81` | 1v1/rekabet vurgusu, Zana hero kartı |
| Üçüncül (gökmavi) | `#38BDF8` | Kategori/mod kartları, quiz gradyanı |
| Dördüncül (lime) | `#8BC53F` | Başarı/tamamlanma, üçüncü mod rengi |
| Ödül (gold — **değişmez**) | `#E9C46A` | Yalnızca coin/ödül/streak — mevcut kural korunur |
| Doğru/Yanlış (**değişmez**) | mevcut `correct`/`wrong` | Quiz geri bildirimi renk kuralı korunur |

`AppTheme` sabit eşlemesi:
- `brandOrange`/`brandOrangeWarm` → indigo `#6C5CE7` / açık indigo `#8B7CF6`
  (gradyan çifti; `primaryGradientStart`/`End` bunları miras alır).
- `playGreen` → lime `#8BC53F` (öğrenme ekranı kimliği).
- `playPink` → `#FF3B81` (değişmez, zaten uyumlu).
- `playCyan` → `#38BDF8` (değişmez, zaten uyumlu).
- `playPurple` → indigo `#6C5CE7` ile birleştirilir (ayrı mor tutulmaz).

### Light/Dark Öncelik Değişikliği

> **GÜNCELLEME (2026-07-15, `fc6d2dd`):** Bu bölümdeki açık-öncelikli karar
> geri alındı — varsayılan tema tekrar **koyu** yapıldı ("TRT Bil Bakalım"
> hissi ilk açılışta olsun diye, bkz. `theme_provider.dart`). Aşağıdaki
> açık-mod zemin rengi (`#FAFAFF`) yalnızca kullanıcı elle açık temaya
> geçtiğinde kullanılır; koyu mod zemin (`#15121F`) varsayılandır. Palet
> (indigo/pembe/gökmavi/lime) değişmedi.

Mevcut sistem **koyu-öncelikli** (`backgroundGradient` varsayılan `bgGradient`).
Yeni sistem **açık-öncelikli** olur: `isLight(context)` mantığı ters çevrilir,
açık palet varsayılan olur. Koyu tema ikincil ama eksiksiz desteklenir — Bubblegum
paleti koyu zeminde de (indigo/pembe tonları hafif parlatılmış) çalışacak şekilde
ayrı bir dark-mode ayarı tanımlanır (artifact-design ilkesi: "her iki temaya aynı
özen").

Açık mod zemin: sıcak beyaz `#FAFAFF` (mevcut `lightBg` yerine).
Koyu mod zemin: `#15121F` (mevcut derin-yeşil `bg` yerine).

## Kültürel Taşıyıcı — Zana/RojMascot

Kültürel kimlik **renk paletinde değil**, mascot'ta taşınır:

- 12 üçgen ışının rengi: sabit altın yerine 4 yeni rengin (indigo/pembe/gökmavi/
  lime) sırayla dönüşümü — kilim sınırındaki dönüşümlü renk şeridi hissi.
  `_RojMascotPainter` içindeki `rayPaint` tek renk yerine ışın index'ine göre
  4 renkten birini seçer.
- Yüz ifadeleri (`RojMood.happy/celebrate/thinking`) ve genel geometri değişmez.

## Bileşen Dili

- Kart radius: mevcut `AppRadius.card` (muhtemelen 12-14px) → **16px** (Pirs'in
  daha yuvarlak, oyunsu hissi).
- **Tam-genişlik mod kartı** (yeni pattern): gradyan dolgu, `border-radius:16`,
  başlık + alt açıklama solda, ikon sağda — `_ModeCard` adında paylaşılan widget.
- **Kategori satırı** (yeni pattern): soft-tint arka plan + renkli daire rozet +
  isim + bedel — `_CategoryRow` adında paylaşılan widget; mevcut kategori
  kartlarının yerini alır.
- **Sonuç 2×2 grid**: `QuizResultScreen`'deki mevcut buton `Row`'u `GridView`/
  `Wrap` 2×2 düzenine döner; birincil (Dîsa Bilîze) dolgu, ikincil outline.
- Quiz şıkları: düz renk yerine hafif gradyan pill butonlar (4 rengin dönüşümlü
  kullanımı, doğru cevap ima edilmez — mevcut kural korunur).
- Işın motifi mascot dışında **kullanılmaz** (yalnızca Zana'ya özgü kalır — aşırı
  tekrar kültürel motifi sıradanlaştırır).

## Ekran Aileleri ve Yerleşim Değişiklikleri

### Paket 0 — Tasarım Temeli
`app_theme.dart` token güncellemesi (yukarıdaki tablo), light-mode varsayılan,
`_RojMascotPainter` renk güncellemesi, `_ModeCard`/`_CategoryRow` paylaşılan
widget'larının oluşturulması.

### Paket 1 — Ana Sayfa ve Bilîze (Oyun Merkezi)
- Ana Sayfa: Zana kartı büyütülür/vurgulanır (pembe gradyan, gölgeli); küçük 2×2
  mod grid'i → tam-genişlik `_ModeCard` listesi.
- Bilîze: "Oda Aç / Kod Bike / Turnuva" tam-genişlik kartlara döner.
- **Yeni ekran**: Kategorî Hilbijêre — quiz kategorisi seçimi ayrı, sade liste
  ekranı olur (şu an muhtemelen gömülü sekme/grid içinde; mevcut
  `categories_tab.dart` bu ekrana taşınır/uyarlanır — kod incelemesi implementation
  planında netleştirilecek).

### Paket 2 — Fêr Bibe (Öğrenme Yolu)
Düğüm-tabanlı öğrenme yolu (Duolingo-tarzı skill tree) **korunur** — bu Pirs'te
olmayan, ZanKurd'a özgü geçerli bir pattern. Yalnızca renk paleti ve düğüm
rozetleri (kilit/tamamlanma/önerilen) yeni tokene geçer.

### Paket 3 — Quiz ve Sonuç
Soru kartı okunabilirliği birinci öncelik (mevcut kural). Şıklar 4 rengin
dönüşümlü kullanımıyla ama doğru cevabı ima etmeden. Sonuç ekranı: trophy +
progress ring hero (pembe/indigo gradyan) + 2×2 aksiyon grid'i.

### Paket 4 — Civak (Topluluk/Liderlik)
Liderlik satırları sadeleştirilir (rank + avatar + isim + skor, tek satır);
kullanıcının kendi satırı indigo tint ile vurgulanır. Arkadaşlar sekmesi mevcut
işlevini korur (çocuk modu kilitleri dahil — bu oturumda eklendi, dokunulmaz).

### Paket 5 — Profil ve Ayarlar
Profil hero (indigo gradyan) + avatar + seviye çubuğu; mastery/strength-map
bölümleri mevcut mantığıyla yeni tokene geçer. Ayarlar: toggle satırları indigo
aktif rengiyle (mevcut switch mantığı değişmez).

### Paket 6 — Kalan Sistem Ekranları
Onboarding, empty/error/loading, dialog, bottom sheet, hikâye modu, seviye
sınavı — yeni token/component ailesine taşınır. Bu paket görsel borcu kapatır.

## Uygulama Stratejisi

- Büyük toplu refactor yapılmaz; paketler sırayla, küçük diff'lerle uygulanır.
- Önce Paket 0 (token + paylaşılan widget), sonra ekran bazlı kullanım.
- Mevcut componentler (AppPanel, ScreenIdentityHeader, PressableCard vb.) çalışıyorsa
  yeniden yazılmaz, yeni token'lara uyarlanır.
- Yeni dependency eklenmez.
- **TDD korunur**: proje kuralı gereği her paket için önce başarısız
  widget/golden test yazılır, sonra uygulanır (CLAUDE.md ve bu oturumun Aşama 1-8
  akışıyla tutarlı).

## Test ve Görsel Doğrulama

Her paket için:

1. `dart format` yalnızca değişen dosyalarda.
2. `dart analyze` — sıfır uyarı hedefi (bu oturumda kurulan standart).
3. İlgili widget testleri; paket sonunda tam `flutter test`.
4. 360px ve 768px genişlikte overflow kontrolü.
5. Light/dark mode karşılaştırması (artifact-design ilkesi: ikinci temaya aynı özen).
6. Web release build + Playwright ile 390×844 mobil ekran görüntüsü.
7. Son pakette canlı doğrulama: build hash, CDN cache purge kontrolü (bu
   oturumda `zankurd.com` deploy'unda karşılaşılan CDN cache sorunu göz önünde
   bulundurulur — bkz. proje hafızası).

## Kapsam Dışı

- Yeni oyun modu veya veri modeli.
- Backend, Supabase schema/RLS, auth veya route davranışı değişikliği.
- Navigasyon modeli değişikliği (hamburger'a geçiş) — açıkça reddedildi.
- Pirs varlıklarının (logo, illüstrasyon, metin) kopyalanması.
- Yeni font/typography sistemi.
- Tüm ekranları tek committe değiştirmek.

## Kabul Kriterleri

- Tüm ekranlar Bubblegum Arcade palet ailesine (indigo/pembe/gökmavi/lime) ait
  görünür; turuncu/mor kalmaz (gold ödül rengi hariç).
- Zana'nın ışın rengi 4 rengin dönüşümü; geometri/ifade davranışı değişmez.
- Mod seçimi ve kategori seçimi tam-genişlik/liste pattern'ine döner (küçük grid
  kalmaz).
- Sonuç ekranı 2×2 aksiyon grid'i kullanır.
- 5 sekmeli alt navigasyon değişmeden kalır.
- Açık mod varsayılan; koyu mod eksiksiz ve okunabilir ikincil tema olarak çalışır.
- 360px genişlikte RenderFlex overflow oluşmaz.
- Mevcut logic testleri geçer; navigation ve backend çağrılarında davranış farkı
  yoktur.

## Bilinen Açık Noktalar (implementation planında netleştirilecek)

- `lib/src/screens/categories_tab.dart`, `home_screen.dart`, `play_hub_screen.dart`
  içindeki mevcut mod/kategori widget yapısının tam kod incelemesi — yeni
  `_ModeCard`/`_CategoryRow` widget'larının nereye entegre edileceği.
- Depoda bu oturumdan önce oluşturulmuş, kısmen örtüşen iki ek spec var:
  `2026-07-12-best-in-class-experience-design.md` ve
  `2026-07-12-kulturel-modern-2-design.md`. Bunların durumu (süpersede mi,
  kısmen uygulanmış mı) implementation planı öncesi kullanıcıyla netleştirilmeli.
