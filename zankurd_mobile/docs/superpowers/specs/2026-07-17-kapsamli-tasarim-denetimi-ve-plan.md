# Kapsamlı Tasarım Denetimi ve Yeniden Hizalama Planı — 17 Temmuz 2026

## Yöntem

Bu denetim iki koldan yapıldı:
1. **Kod taraması:** `lib/src/screens` ve `lib/src/widgets` altında tüm
   `Color(0xFF...)` hardcoded renk kullanımları çıkarıldı (98 adet), her
   dosya tek tek incelendi.
2. **Canlı gezinti:** `flutter run -d web-server` ile uygulama açılıp
   **20+ ekran** (Home, Kategorî, Alt kategori, Seviye yolu, Quiz, Doğru/
   Yanlış geri bildirim, Sonuç, İnceleme, Rêz/Liderlik, Profil, Ayarlar,
   Mağaza, Arkadaşlar, Civak û Lîg, Pêşbazî hub, 1vs1 Matchmaking, Bot maçı,
   Turnuva, Çark, Soru Öner, Avatar Editör) uçtan uca gezildi, ekran
   görüntüsü alınıp mockup'larla (`ÖRNEK TASARIM/`) ve önceki fazların
   hedefiyle karşılaştırıldı.

## Tek cümlelik teşhis

**Uygulama iki farklı tasarım dilinin üst üste bindiği bir yama işi gibi
görünüyor** — çünkü yeniden hizalama çalışması yalnızca *mockup'ta doğrudan
referansı olan* ekranlara (Home, Kategorî, Quiz, Sonuç, Liderlik, Profil'in
üst kısmı) uygulandı; mockup'ta karşılığı olmayan ekranlar (Pêşbazî hub,
Turnuva, Çark, Mağaza, Avatar renk seçici, Rozet kartları, Ayarlar/Profil/
Mağaza'nın "hero" başlıkları) "en yakın anlamlı" gerekçesiyle atlandı ve
**gerçekte hiç dokunulmadı** — sadece birkaç paylaşılan token (playPink,
playCyan, playPurple) değişince yüzeysel olarak "palete yakınlaştı" ama
altındaki widget'lar (Container renkleri, gradyanlar, ikon setleri) eski
"Bubblegum Arcade / Pirs-inspired" döneminden **aynen kaldı**.

Sonuç: kullanıcı bazı ekranlarda (Home, Quiz, Kategorî) özenle çizilmiş,
tutarlı bir koyu-yeşil-altın kimlik görürken, bir tık ötede (Pêşbazî →
Turnuva veya Çark, ya da Profil → Mağaza) birdenbire eski, alakasız bir
renk paletine düşüyor. Bu geçiş **tutarsızlık hissi** yaratıyor — "olmamış"
duygusunun teknik karşılığı budur.

## Bulgu 1 — Üç farklı görsel dil bir arada

| Dil | Nerede | Özellikler |
|---|---|---|
| **A — Hedef (doğru)** | Kategorî, Home metrik şeridi, Rêz/Liderlik, İnceleme, Ayarlar alt bölümleri, Hevalên Min | Koyu düz yüzey, ince sınır, sol ikon çipi, kompakt satır |
| **B — Eski kalıntı (sorunlu)** | Pêşbazî ana kartları, Profil üst "hero" kartı, Mağaza tamamı, Ayarlar üst "hero", Avatar Editör hero + renk paleti, Rozet/Koleksiyon kartları, **Turnuva ekranının tamamı** | Büyük renkli/altın gradyan kart, köşede büyük soluk ikon (watermark), glow gölge — "Bubblegum Arcade" / "Pirs-inspired" (2026-07-10/12) döneminden kalma |
| **C — Faz 0-1 ürünü** | Yalnızca Home'un en üstü (karşılama satırı) | Mockup-3 ince header |

**Turnuva ekranı özel durum:** Referans mockup'larda (11 tanesinde) turnuva
yok; "en yakın anlamlı" bırakılan bu ekran aslında **hiçbir yeniden tasarım
turundan geçmemiş** — büyük sarı-altın gradyan kart + tek büyük kupa ikonu,
uygulamanın geri kalanıyla hiç örtüşmüyor.

## Bulgu 2 — Palet dışı renk kalıntıları (kod + ekranda doğrulandı)

| Dosya/Ekran | Sorun | Kanıt |
|---|---|---|
| `spin_wheel_screen.dart` (Çark) | 8 segment tam eski "gökkuşağı/candy" paleti: coral, gold-yellow, vivid green, bright blue, orange, amethyst, **sky `0xFF38BDF8`** (playCyan'ın eski değeri, token değişince literal güncellenmedi), **hot pink `0xFFFF3B81`** (playPink'in eski değeri) | Ekran görüntüsüyle doğrulandı — casino/oyuncak hissi, marka kimliğiyle sıfır bağlantı |
| `lib/src/config/avatar_presets.dart` (`avatarColors`) | 8 renk tamamen jenerik "Tailwind" paleti (`#E94560, #7C3AED, #2563EB, #10B981, #F59E0B, #EC4899, #0EA5E9, #F97316`) | Marka renklerinden (`#3DA968` yeşil, `#E5533D` nar, `#E7B53C` altın, `#2E9E93` teal, `#6B3A7A` erik) hiçbiri yok |
| `badge_widget.dart` | Eski indigo/lacivert (`0xFF1A1A2E`, `0xFF2A3B5C`, `0xFF909090`/`0xFF656565` gri), parlak turkuaz `0xFF00D68F` | Faz 0 palet geçişinden hiç geçmemiş; Rozet Koleksiyonu kartlarında mor ton ekranda görüldü |
| Mağaza (`shop_screen.dart`) | "Rozeta VIP" kartı mavi/lacivert gradyan | Ekranda görüldü, palete hiç uymuyor |

## Bulgu 3 — Ekran mükemmerliği / kafa karışıklığı

**"Rêz" sekmesi (Liderlik) ve Profil → "Civak û Lîg"** neredeyse birebir
aynı ekranı (aynı podyum, aynı sıralama listesi) gösteriyor; Civak û Lîg
üstüne sadece "Lig/Heval" toggle ve kategori filtre çubuğu eklenmiş. İki
farklı navigasyon yolunun aynı hedefe götürmesi kullanıcıyı "bunlardan
hangisi asıl?" diye duraksatır.

## Bulgu 4 — İçerik kalitesi (tasarım değil ama izlenimi bozuyor)

- Bir soruda dil KU seçiliyken **şıklar tamamen Türkçe** çıktı: "Olayları
  zaman sırasına koyma", "Irak Kürt ulusal hareketi" vb. (CLAUDE.md'de
  zaten not edilen "~207 Türkçe prompt" sorununun canlı örneği)
- Mock/gerçek veride tutarsız isimlendirme: liderlik listesinde "rana" ve
  "Ranakêêê" gibi büyük/küçük harf karışık kullanıcı adları

## Bulgu 5 — Küçük ama gerçek metin taşma/kırpma sorunları

- Home: "Kodê tevlî bi…" (Kodla katıl butonu metni kesiliyor)
- Mağaza: "Zivirîna Zêde ya Ç…" (ürün başlığı kesiliyor)
- Quiz son soru: metrik çipinde "10/…" (Pirs sayacı iki haneli olunca kesiliyor)

## Neden buraya kadar geldi — dürüst kök neden

1. Her yeniden hizalama turu (benim fazlarım + Codex + Antigravity) **kendi
   dar kapsamına** odaklandı: ben mockup'a birebir karşılığı olan ekranlara,
   Antigravity altyapı/bug'lara, kimse **uygulamanın tamamını tek seferde
   uçtan uca gezip** tutarlılığı doğrulamadı.
2. "Zaten hizalı, dokunmaya gerek yok" değerlendirmeleri (özellikle Faz 5-6
   için yaptığım) **yüzeyseldi** — ekranı açıp içine girmeden, sadece isim/
   amaç bazında "muhtemelen OK" diye işaretlendi.
3. Paylaşılan token'ları (`AppTheme.playCyan` vb.) değiştirmek, o token'ı
   *literal* olarak kopyalayan widget'ları (Çark'taki segment listesi gibi)
   otomatik düzeltmiyor — bu tür literal kopyalar taramada gözden kaçtı.
4. Mockup'ların kapsamadığı ekranlar (Turnuva, Çark, Mağaza'nın ürün
   kartları, Avatar renk seçici) için **hiç yeni bir hedef tanımlanmadı** —
   "en yakın anlamlı" ifadesi pratikte "dokunma" anlamına geldi.

## Önceliklendirilmiş Aksiyon Planı

### Faz 7 — Palet dışı renk temizliği (yüksek etki, düşük risk)
1. `spin_wheel_screen.dart`: 8 segment rengini marka paletinden türetilmiş
   8 tona çevir (yeşil, altın, nar, teal, erik moru, terracotta, hardal,
   koyu yeşil gibi — canlılığı korurken aileye sok).
2. `avatar_presets.dart`: `avatarColors` listesini marka paletinden
   türetilmiş 8 tona çevir. **Dikkat:** bu renkler `profiles.avatar_color`
   kolonunda saklanıyor olabilir — mevcut kullanıcı verisini bozmadan (hex
   string aynı kalabilir, sadece hangi hex'lerin *seçilebilir* olduğu
   değişir) ilerlenmeli.
3. `badge_widget.dart`: eski indigo/lacivert/turkuaz tonlarını temizle,
   dark/light iki moda da palet token'larından besle.
4. Mağaza "Rozeta VIP" kartını marka rengine çevir.

### Faz 8 — "B dili" ekranlarını "A diline" taşı (yüksek etki, orta risk)
Hedef: büyük gradyan hero kart + watermark ikon deseni yerine, Kategorî'de
kurulan dil (koyu yüzey + ikon çipi + kompakt satır) veya duruma göre
mockup ruhuna en yakın yeni bir düzen.
1. **Turnuva ekranı** — sıfırdan, mockup'ların koyu-sıcak sistemine göre
   (liste/detay kartı, gradyan hero değil).
2. **Pêşbazî hub kartları** — büyük gradyan yerine kompakt liste/kart
   karışımı (mockup 3'teki "Lîstika lez" küçük kart diliyle tutarlı).
3. **Profil hero, Ayarlar hero, Avatar Editör hero** — üçü de aynı "sarı-
   altın gradyan" kalıbını paylaşıyor; ya bilinçli bir "başlık şeridi" alt
   dili olarak marka rengine (yeşil/nar) çevrilip *tutarlı bir aile* haline
   getirilmeli, ya da Kategorî'nin sade üst başlığına indirgenmeli.
4. **Rozet/Koleksiyon kartları** — mor tondan çıkar, kilitli/açık durumları
   marka paletiyle göster.

### Faz 9 — Ekran mükemmerliğini gider
- Rêz sekmesi ile Civak û Lîg'in ilişkisini netleştir: ya Civak û Lîg'i
  Rêz'in bir alt-filtresi olarak birleştir, ya da ikisi arasında net bir
  amaç farkı kur (örn. Rêz = küresel sıralama, Civak û Lîg = yalnız
  arkadaş/lig bazlı) ve bunu ekranda açıkça belirt.

### Faz 10 — İçerik ve metin kalitesi
- KU dilinde Türkçe kalan şıkları tarayıp çevir (kapsamlı bir ayrı iş;
  CLAUDE.md'deki "~207 Türkçe prompt" ile aynı kalem, muhtemelen aynı kök).
- Metin taşan 3 nokta (Home Kodla-katıl, Mağaza ürün adı, Quiz Pirs sayacı)
  tek tek `maxLines`/`Expanded`/kısaltma ile düzeltilir.
- Mock veri kullanıcı adlarındaki büyük/küçük harf tutarsızlığı düzeltilir.

## Doğrulama kapısı (her faz sonunda)
- `dart analyze` temiz, `flutter test` tam yeşil.
- Değişen her ekran **tek tek tarayıcıda açılıp** ekran görüntüsü alınır —
  "muhtemelen OK" değerlendirmesi bu turda kesinlikle tekrarlanmayacak.
- Faz 8 bitince **uygulamanın tamamı yeniden uçtan uca gezilir** (bu
  denetimde izlenen 20+ ekranlık rota) ve üç-dil sorunu tekrar kontrol edilir.
