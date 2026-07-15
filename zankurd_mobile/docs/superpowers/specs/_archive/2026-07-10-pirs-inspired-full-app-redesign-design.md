# ZanKurd Pirs-Inspired Full App Redesign

**Tarih:** 2026-07-10  
**Durum:** SÜPERSEDE EDİLDİ (2026-07-12) — kullanıcı turuncu marka rengini bırakıp
tamamen yeni bir palet seçti. Güncel spec:
[2026-07-12-bubblegum-arcade-redesign-design.md](2026-07-12-bubblegum-arcade-redesign-design.md).
Bu dosya yalnızca tarihsel referans için tutuluyor; layout/erişilebilirlik ilkeleri
büyük ölçüde yeni spec'e taşındı, renk sistemi geçersiz.

## Amaç

ZanKurd'u mevcut koyu ve ağır premium kimlikten, Pirs uygulamasındaki açık zemin,
turuncu karşılama alanı ve büyük renkli oyun kartlarının enerjisinden yararlanan;
ancak daha modern, esnek ve ZanKurd'a özgü bir sisteme taşımak.

Başarı ölçütü: İlk bakışta eğlenceli ve erişilebilir, uzun kullanımda yorucu olmayan,
çocukça görünmeden her yaşa hitap eden, tüm ekranlarda aynı ürüne ait hissi veren UI.

## Mevcut Durum ve Korunacaklar

Grok/önceki çalışmalar onboarding, auth, home, kategori, quiz, sonuç, profil,
öğrenme, mağaza, liderlik, turnuva ve ikincil ekranlarda önemli polish yaptı.
`AppTheme`, `ScreenIdentityHeader`, `PressableCard`, state widget'ları, kategori
görselleri, seviye yolu ve responsive davranış yeniden kullanılacak.

Korunacak sözleşmeler:

- Navigation, route ve event handler davranışı.
- Quiz skoru, zamanlama, joker, coin ve XP hesapları.
- Oda, matchmaking, 1vs1, takım, turnuva ve contest akışları.
- Provider, repository, service, Supabase, auth ve veritabanı sözleşmeleri.
- Mevcut kategori görselleri ve ZanKurd logo/marka kimliği.
- Kurmancî/Türkçe dil seçimi ve tüm mevcut test key'leri.

## Referans Kullanım Sınırı

Pirs'ten alınacak üst düzey ilkeler:

- Açık nötr ana zemin üzerinde turuncu profil/karşılama alanı.
- Büyük, kolay taranan, mod bazlı renkli oyun kartları.
- Kart içinde düşük opaklıklı işlev ikonu/filigranı.
- Profil istatistiklerinin tek bakışta görünmesi.
- Sonuç ekranında güçlü skor vitrini ve renkli tekrar/inceleme aksiyonları.

Birebir alınmayacaklar: logo, özgün illüstrasyonlar, ikon çizimleri, metinler,
ekran kompozisyonu, gradient değerleri ve mağaza görselleri. ZanKurd tasarımı
referansla benzer enerji taşıyacak, kopya olmayacak.

## Görsel Sistem

### Renkler

- Ana zemin: `#F4F5F7`; kart: `#FFFFFF`; ana metin: `#18211D`.
- Marka/ana CTA: turuncu `#F47A32`; sıcak vurgu `#FF9F1C`.
- Öğrenme: yeşil `#58B96B`; 1vs1: pembe `#E72F8C`.
- Oda/takım: turkuaz `#3BC7C1`; özel mod: mor `#8A62D3`.
- Coin/liderlik/ödül: altın `#F4BE3A`.
- Dark mode: `#102820` temel zemin; aynı accent ailesinin kontrastı ayarlanmış hali.

Renk oranı: yaklaşık yüzde 65 açık/sakin yüzey, yüzde 25 mod rengi, yüzde 10
ödül ve CTA vurgusu. Gradient yalnızca header, hero, mod kartı ve sonuç vitrini
gibi odak yüzeylerinde kullanılacak.

### Component Dili

- Kart radius standardı `16`; büyük hero/banner en fazla `18`.
- İnce border ve yumuşak gölge; kalın 3D gölge ve glow kullanılmayacak.
- Filled primary CTA turuncu; ikincil CTA beyaz/outline veya ekran accent rengi.
- Chip'ler küçük, içerik kadar geniş ve tek satır; taşmada ellipsis veya wrap.
- Progress bar ince, yüksek kontrastlı ve ilgili ekran accent renginde.
- İkonlar Lucide/Material ailesinden tutarlı; dekoratif ikonlar yüzde 8-14 opaklıkta.
- Kilim deseni yalnızca seçili hero/ödül yüzeylerinde düşük opaklıkta kalacak.
- Tipografi ağırlıkları çoğunlukla 600-800; ekran genelinde sürekli 900 kullanılmayacak.

## Responsive ve Erişilebilirlik

- Telefon: tek kolon; tablet/desktop: anlamlı yerlerde 2-4 kolon, içerik max-width.
- 360 px genişlik ve 1.3 text scale temel dar ekran kontrolü.
- Kurmancî/Türkçe başlıklar `maxLines`, `overflow` ve uygun line-height taşır.
- Tıklanabilir alanlar en az 44x44; kontrast WCAG AA hedefler.
- Desktop'ta kartlar tüm genişliğe kontrolsüz yayılmaz.
- Light ve dark mode aynı bilgi hiyerarşisini korur; auth ekranları da temaya uyar.

## Ekran Aileleri

### Paket 0 — Tasarım Temeli

`app_theme.dart`, tema varsayılanı, ortak card/button/chip/progress/header stilleri,
navigation bar ve responsive container. Light mode varsayılan olur; dark mode korunur.
Eski sabit koyu auth teması kaldırılır.

### Paket 1 — Giriş ve Ana Deneyim

Splash, onboarding, sign-in, sign-up, name gate, app shell, home, hero, quick play,
günlük görev ve Zana kartı. Ana sayfa Pirs benzeri turuncu profil header + renkli
mod kartları düzeninin ZanKurd uyarlaması olur.

### Paket 2 — Keşif ve Öğrenme

Kategori, alt-kategori, öğrenme alanı ve seviye yolu. Mevcut kategori görselleri
korunur; kart metadata, mastery, progress ve CTA hiyerarşisi yeni sisteme taşınır.

### Paket 3 — Quiz ve Sonuç

Quiz, sonuç, cevap inceleme ve favori sorular. Soru okunabilirliği birinci öncelik;
renk seçenekleri ayırır ama doğru cevabı önceden ima etmez. Sonuç ekranı renkli
skor vitrini, ring, metric tile ve iki belirgin CTA kullanır.

### Paket 4 — Rekabet ve Sosyal

Matchmaking, room, 1vs1/team, contest, tournament, leaderboard ve friends.
Bekleme/bağlantı durumları açıkça ayrılır; oda kodu ve oyuncu durumları dar ekranda
taşmaz. Liderlik altın, 1vs1 pembe, takım/turkuaz kimlik taşır.

### Paket 5 — Profil ve Ekonomi

Profil, avatar editor, shop, spin wheel ve settings. Bakiye, fiyat, sahip olunan
durum, rozet ve tema ayarları aynı component ailesine alınır. Satın alma ve ödül
mantığı değiştirilmez.

### Paket 6 — Kalan Sistem Ekranları

Review, empty/error/loading, bildirim, dialog, bottom sheet ve yardımcı ekranlar.
Bu paket görsel borcu kapatır ve tüm edge state'leri light/dark olarak doğrular.

## Uygulama Stratejisi

- Büyük toplu refactor yapılmaz; paketler sırayla ve küçük diff'lerle uygulanır.
- Önce ortak token/component değişikliği, sonra ekran bazlı kullanım.
- Her pakette logic diff'i ayrıca denetlenir; handler ve async çağrılar korunur.
- Grok'un mevcut componentleri çalışıyorsa yeniden yazılmaz, yeni görsel dile uyarlanır.
- Yeni dependency eklenmez; mevcut Flutter/Material araçları kullanılır.

## Test ve Görsel Doğrulama

Her paket için:

1. `dart format` yalnızca değişen Dart dosyalarında.
2. `dart analyze`.
3. İlgili widget/golden testleri; paket sonunda `flutter test`.
4. Flutter web release build.
5. Playwright ile 390x844, 768x1024 ve 1440x900 ekran görüntüleri.
6. Light/dark, uzun metin, loading/empty/error ve navigation smoke kontrolü.
7. Son pakette canlı `zankurd.com` ile build hash, cache ve Lighthouse doğrulaması.

## Kapsam Dışı

- Yeni oyun modu veya veri modeli.
- Backend, Supabase schema/RLS, auth veya route davranışı değişikliği.
- Pirs varlıklarının kopyalanması.
- Tüm ekranları tek committe değiştirmek.

## Kabul Kriterleri

- Tüm ekranlar açık, renkli Pirs-inspired ZanKurd ailesine ait görünür.
- Dark mode okunabilir ve ikincil tema olarak eksiksiz çalışır.
- 360 px genişlikte RenderFlex overflow oluşmaz.
- Ana CTA, mod kartı, progress, chip ve input stilleri ekranlar arasında tutarlıdır.
- Mevcut logic testleri geçer; navigation ve backend çağrılarında davranış farkı yoktur.
- Canlı deploy sonrası eski build cache'te kalmaz ve kritik assetler 200 döner.
