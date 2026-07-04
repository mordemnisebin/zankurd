# Sign-in ve Ana Sayfa Yeniden Tasarımı

**Tarih:** 2026-07-04
**Durum:** Onaylandı (kullanıcı tarafından, brainstorming oturumunda)

## Bağlam ve Motivasyon

Kullanıcı geri bildirimi iki noktaya işaret etti:

1. **Sign-in ekranı** (`lib/src/screens/sign_in_screen.dart`): Google ve Misafir girişi butonları "çok küçülmüş" hissi veriyor. Kök neden boyut değil, **görsel hiyerarşi**: bu iki buton ince çerçeveli (`OutlinedButton`, saydam arka plan) ve e-posta/şifre formunun *altında*, ikincil bir konumda duruyor — oysa bu muhtemelen en çok kullanılan giriş yollarıdır (misafir modu ve Google, hesap açmadan hızlı giriş sağlar).
2. **Ana sayfa** (`lib/src/screens/home_screen.dart`): "Kalabalık/karışık" hissi veriyor ve kategoriler bölümü **Kategori sekmesiyle (`categories_tab.dart`) birebir aynı içeriği tekrar ediyor** — aynı kategori kartları, aynı ustalık rozetleri, aynı görseller. Ayrıca üst üste 6 büyük, tam-genişlik, doygun renkli kart (Oda Kur/Katıl, 1v1, Günün Yarışması, Çark, Turnuva, Görevler) + kategori ızgarası + bir "Örnek Soru" kartı, aşırı dikey kaydırma ve görsel yorgunluk yaratıyor.

Kullanıcı ile karşılıklı onaylanan karar: kategori ızgarası ana sayfadan **tamamen kaldırılacak** (teaser/önizleme bile bırakılmayacak) — kategori keşfi tamamen Kategori sekmesinin sorumluluğu olacak. Görsel yön için kullanıcı tasarımcıya güvendi: "şık, modern, sade olmasın, renksiz olmasın, renkli olduğu kadar okunaklı, kontrastlara dikkat et, profesyonel hissi versin."

## Kapsam

Bu spec şu dosyaları kapsar:
- `lib/src/screens/sign_in_screen.dart` (yeniden düzenleme)
- `lib/src/screens/home_screen.dart` (kart kaldırma + yeni bölüm)
- Yeni widget: `lib/src/screens/home/quick_play_grid.dart` (4 aksiyonu birleştiren kompakt 2x2 ızgara)
- Silinecek/artık home'dan çağrılmayacak: `lib/src/screens/home/category_grid.dart` kullanımı home_screen'den kalkıyor (dosyanın kendisi silinmiyor — `categories_tab.dart` kendi `_CategoryCard`'ını kullanıyor, `home/category_grid.dart` başka yerden çağrılmıyorsa silinebilir; plan aşamasında doğrulanacak)
- Etkilenmeyen: `categories_tab.dart`, `home/hero_card.dart`, `home/battle_1v1_card.dart`, `home/daily_quiz_card.dart`, `home/spin_wheel_card.dart`, `home/tournament_card.dart`, `home/daily_missions_card.dart` (içerikleri değil, home_screen'deki *yerleşimleri* değişiyor — battle/daily-quiz/spin-wheel/tournament kartları artık ayrı tam-genişlik satırlar yerine yeni `QuickPlayGrid` içinde kompakt tile olarak render edilecek, bu da bu 4 dosyanın kendi widget'larının kullanılmayıp yerine yeni kompakt tile widget'ları yazılacağı anlamına gelir — bkz. "Ana Sayfa Tasarımı" bölümü)

Kapsam dışı: header (karşılama/coin/streak), onboarding, sign_up_screen, diğer sekmeler (Kategori, Liderlik, Profil), Supabase/backend — hiçbiri değişmiyor.

## 1. Sign-in Ekranı Tasarımı

### Yapısal değişiklik: buton sırası ve hiyerarşi

**Şimdiki sıra:** Logo → Başlık → [E-posta alanı, Şifre alanı, Şifremi unuttum] → Giriş Yap (gradyan buton) → "AN JÎ" ayracı → Google (outline) → Misafir (outline) → Kayıt ol linki

**Yeni sıra:** Logo → Başlık → **Google (dolgun, beyaz pill)** → **Misafir (dolgun, marka gradyanlı pill)** → "An jî e-posta ile" ayracı → [E-posta alanı, Şifre alanı, Şifremi unuttum] → Giriş Yap (gradyan buton, aynı kalır) → Kayıt ol linki

Gerekçe: Google ve Misafir en hızlı, en az sürtünmeli yollar; bunları en üste, en görünür konuma taşımak modern uygulamaların (Duolingo, Discord, Notion mobil) izlediği örüntüdür. E-posta/şifre formu kaybolmuyor, kaldırılmıyor — sadece ikinci sıraya, "zaten hesabı olan/bunu tercih eden" kullanıcı için bir seçenek olarak konumlanıyor.

### Buton görselleri

**Google butonu:**
- Beyaz (`#FFFFFF`) dolgu, koyu lacivert metin (`AppTheme.bgDeep` veya `textPrimary`'nin koyu karşılığı — asıl kontrast şart: beyaz zemin üzerinde net okunaklı koyu metin)
- Sol tarafta "G" harfi (mevcut yaklaşım korunur — gerçek Google logosu asset'i eklenmez, ek bağımlılık yaratılmaz), `AppTheme.accent` (neon pembe) renginde, kalın (`FontWeight.w800`), biraz büyütülmüş (20-22px)
- Belirgin ama yumuşak gölge (`BoxShadow`, siyah/koyu ton, düşük opaklık) — koyu arka plana karşı "yükseliyor" hissi versin
- Yükseklik ~56-58px (mevcut ~48'den artırılıyor), köşe yarıçapı 16 (mevcut outline butonların 12'sinden biraz daha yumuşak/modern)

**Misafir butonu:**
- `AppTheme.homeHeaderGradient` (mor `#6F61C0` → pembe `#FF4B91`) dolgu — bu gradyan zaten ana sayfa header'ında kullanılıyor, yeniden kullanmak marka tutarlılığı sağlıyor ve birincil "Giriş Yap" butonunun `accentGradient`'ından (pembe→turuncu) görsel olarak ayrışıyor, böylece iki farklı amaçlı buton karışmıyor
- İkon (`Icons.person_outline` veya dolgun `Icons.person_rounded`) beyaz dairesel rozet içinde (uygulamanın diğer kartlarında zaten kullanılan ikon-rozet deseniyle tutarlı — bkz. `DailyQuizCard`, `SpinWheelCard`)
- Beyaz, kalın metin
- Aynı yükseklik/köşe yarıçapı Google butonuyla hizalı; kendi tint'ine göre gölge (`AppTheme.violet.withValues(alpha: ~0.35)`)

**Ayraç:** "AN JÎ" yerine bağlama uygun yeni metin: KU "An jî bi e-peyamê" / TR "Veya e-posta ile" — mevcut çizgi+metin deseni korunur, sadece konumu formun üstüne değil Google/Misafir'in altına, formun üstüne taşınır.

**E-posta formu:** Fonksiyonel olarak aynı (validasyon, şifre göster/gizle, şifremi unuttum linki) — sadece görsel ağırlığı hafifletilir (etiket font ağırlığı biraz azaltılabilir), tamamen gizlenmiyor/accordion'a alınmıyor (ek state/animasyon karmaşıklığı ve mevcut `GlobalKey<FormState>` akışını bozma riskini önlemek için).

### Geniş ekran (tablet/masaüstü, `isWide`) davranışı

Mevcut iki-kolonlu yapı korunur (sol: logo+başlık, sağ: form+butonlar), ama sağ kolonun İÇİNDEKİ sıralama aynı mantıkla değişir: Google+Misafir üstte, ayraç, form altta. `denseWide` (kısa/yatay dar alan) durumunda Google+Misafir yan yana (Row) kalabilir — bu zaten mevcut davranış, korunuyor.

### Değişmeyenler
- Logo, animasyonlar (`LoadAnimationSequence`), arka plan geometrik şekiller, dil değiştirici (KU/TR), "Hesabın yok mu? Kaydol" linki, tüm hata mesajları ve auth mantığı (`AuthProvider` çağrıları) — sıfır davranış değişikliği, sadece görsel/yerleşim.

## 2. Ana Sayfa Tasarımı

### Kaldırılanlar
- `SectionHeader(title: 'Kategorî'/'Kategoriler')` + `CategoryGrid(...)` bloğu — hem dar hem geniş ekran dallarından tamamen kaldırılıyor.
- `SectionHeader(title: 'Pirsa Nimûne'/'Örnek Soru')` + `QuestionCard(...)` bloğu — tamamen kaldırılıyor (Hero kartındaki "Tenê pratîk bike" / "Tek başına pratik" butonuyla işlevsel olarak zaten aynı akışa (quiz ekranı) gidiyordu, tekrar niteliğindeydi).

### Yeni yapı (dar ekran / telefon, dikey akış)

1. **Header** (`_buildGeometricHeader`) — değişmiyor.
2. **Hero kartı** (`HeroCard` — Oda Kur / Kodla Katıl / Tek başına pratik) — tek "yıldız" kart olarak tam genişlikte kalıyor, mevcut görseli/animasyonu korunuyor. Bu, uygulamanın gerçek ayırt edici özelliği (canlı çok oyunculu oda) olduğu için öne çıkarılmaya devam ediyor.
3. **Yeni bölüm başlığı:** KU "Zû Bilîze" / TR "Hemen Oyna"
4. **`QuickPlayGrid`** (yeni widget) — 2x2 kompakt ızgara, 4 tile:
   - 1v1 Düello (kırmızı-turuncu `#FF416C`→`#FF4B2B`, `Icons.bolt_rounded`, "VS" motifi küçültülmüş biçimde)
   - Günün Yarışması (altın-amber `AppTheme.gold`→`#FF8F00`, `Icons.today_rounded`)
   - Günün Çarkı (mor `AppTheme.violet`→`AppTheme.secondaryAccent`, `Icons.casino_outlined`)
   - Turnuva (**turkuaz-zümrüt** `#00BFA5`→`#00897B` — mevcut altın tonundan kasıtlı olarak farklılaştırıldı, çünkü Günün Yarışması zaten altın; iki bitişik kutunun aynı renk ailesinde olması ayırt edilebilirliği azaltır)

   Her tile: ikon (beyaz, üstte), kısa başlık (1 satır, kalın), tek satır alt metin (opsiyonel, yer varsa), tamamı ~110-130dp yükseklikte kare/dikdörtgen kutu, kendi rengiyle dolgun ve okunaklı (beyaz metin/ikon, yeterli kontrast — mevcut kartlarda zaten kanıtlanmış doygunluk seviyeleri kullanılıyor). Dokunma tüm tile alanını kapsar.

5. **Günlük Görevler kartı** (`DailyMissionsCard`) — aynı kalıyor, konumu Quick Play ızgarasının hemen altına.
6. Kategori ve Örnek Soru blokları yok — sayfa görevler kartıyla (+ alt boşluk) bitiyor.

### Geniş ekran (`isWide`) davranışı

Mevcut iki-kolonlu (sol/sağ) yapı, yeni içerikle güncellenir: sol kolon Hero kartı + Görevler kartı; sağ kolon `QuickPlayGrid` (burada 2x2 yerine tek satır 4-across veya 2x2 — geniş kolon genişliğine göre plan aşamasında karar verilecek, ama kavramsal olarak "4 kompakt tile bir arada" ilkesi korunur). Kategori/Örnek Soru blokları geniş ekrandan da tamamen kalkıyor.

### Renk/okunabilirlik ilkesi (her iki ekran için)

- Her renkli blok/tile, üzerindeki beyaz metin/ikonla yeterli kontrast sağlamalı (mevcut kartlarda zaten kullanılan doygun/orta-koyu ton aralığında kalınacak — WCAG AA'ya yakın, tam ölçüm gerekmez çünkü aynı ton ailesi zaten üretimde test edilmiş durumda).
- Palet, `AppTheme` içindeki var olan renklerden seçilir (yeni ham hex değer yalnızca Turnuva tile'ının farklılaştırılması için ekleniyor: turkuaz-zümrüt); marka kimliği dışına çıkılmıyor.
- "Sade olmasın, renksiz olmasın" talebi: azaltma sayı/dikey alan üzerinden yapılıyor (6 büyük kart → 1 büyük + 4 kompakt tile + 1 orta kart), renk çeşitliliği ve doygunluk korunuyor/hatta tile'lar için netleştiriliyor.

## Test ve Doğrulama Notları (implementasyon planına girdi)

- `test/widget_test.dart` içinde `home_screen` ile ilgili testler (kategori/örnek soru metinlerine referans var mı) plan aşamasında taranacak; bu spec yazılırken yapılan hızlı taramada doğrudan "Kategorî"/"Pirsa Nimûne"/"Örnek Soru" string'i widget_test.dart içinde bulunamadı, ancak `HomeScreen` widget testleri (varsa) yeni yapıya göre güncellenmeli.
- `sign_in_screen.dart` ile ilgili testler (buton bulma, form validasyonu) varsa buton arama sırası/ebeveyn yapısı değiştiği için gözden geçirilmeli.
- `dart analyze` + `flutter test` (tam süit, mevcut 240 test) yeşil kalmalı.
- Uygulama web/tarayıcı üzerinden görsel olarak doğrulanacak (Playwright ile ekran görüntüsü) — özellikle buton kontrastı ve yeni QuickPlayGrid'in taşma yapmadığı teyit edilecek.

## Açık Kalan Küçük Kararlar (plan aşamasında netleşecek)

- `home/category_grid.dart` dosyasının tamamen silinmesi mi yoksa öylece bırakılması mı (başka yerden import edilip edilmediği kontrol edilecek).
- QuickPlayGrid'in wide-screen'de tam olarak kaç sütun/ne oranla dizileceği.
- Google butonundaki "G" harfinin tam stilinin (daire rozet içinde mi, düz mü) son hali — spec bu konuda esnek bırakıyor, uygulama sırasında görsel olarak en iyi hissettiren seçilecek.
