# ZanKurd Karmaşıklık Giderme ve Tasarım Sadeleştirme

**Tarih:** 2026-07-15 · **Talep:** "Uygulamaya kapsamlı analiz yap, canlıda
zankurd.com'a da bak, karmaşıklık karşıtı, tasarım düzeltici, güzelleştirici
bir plan çıkar."

## Denetim yöntemi

Kod tabanı ve git geçmişi (2026-06-16 → 2026-07-15 arası, ~50 UI dokunan
commit) incelendi; `docs/superpowers/specs/` altındaki tüm redesign
dokümanları okundu; `docs/screenshots/phase2b`, `phase2c` altındaki en güncel
ekran görüntüleri incelendi. Canlı `zankurd.com` bu oturumun önizleme
aracıyla açılmaya çalışıldı; araç genel bir zaman aşımı sorunu yaşadı
(kontrol amaçlı `example.com` de aynı şekilde başarısız oldu — ZanKurd'a özgü
değil). DOM/network incelemesi (`main.dart.js` 200 döndü, ama CanvasKit
dosyaları hiç istek olarak görülmedi, `flt-scene` boş kaldı) zayıf bir sinyal
verdi ama görsel doğrulama yapılamadı; **kullanıcı canlı siteyi kendi
tarayıcısında doğrulayacak** (bkz. Faz 5).

## Bulgular

**1. Karar çakışması (spec ↔ kod tutarsızlığı)**
Tema varsayılanı 5 günde 3 kez değişti:
- 2026-07-10 (`2026-07-10-visual-redesign-design.md`, K1): koyu-öncelikli
  yapıldı.
- 2026-07-12 (`da28ce1`, Bubblegum Arcade paleti): açık-öncelikliye
  çevrildi, turuncu/mor terk edildi, indigo `#6C5CE7`/pembe `#FF3B81`/
  gökmavi `#38BDF8`/lime `#8BC53F` geldi.
- 2026-07-13 (`fc6d2dd`, "tasarım denetiminde bulunan 3 eksiği gider"):
  varsayılan tekrar koyuya çevrildi.

Sonuç: `2026-07-12-bubblegum-arcade-redesign-design.md` hâlâ "açık-öncelikli"
yazıyor ama kod (`theme_provider.dart`) koyu döndü. Aynı 48 saatlik pencerede
5 farklı "tam uygulama yeniden tasarımı" spec'i yazılmış
(`pirs-inspired-full-app-redesign`, `kulturel-modern-2`,
`best-in-class-experience`, `bubblegum-arcade-redesign`, ve 07-10'un
kendisi), 3'ü birbirini süpersede etmiş. Bu, iyileştirici iterasyondan çok
kararsızlık/döngü belirtisi.

**2. İçerik tekrarı**
Sereke (ana) ve Bilîze (oyun) sekmeleri aynı 4 oyun modu kartını birebir
tekrarlıyordu; `fc6d2dd` bunu QuickPlayGrid'i yalnız Bilîze'de bırakıp
Sereke'ye teaser kart koyarak düzeltti. Bu örnek, benzer kopyaların başka
ekran çiftlerinde de (`categories_tab.dart` / `subcategory_screen.dart`,
home günlük kartları / learning ekranı) olabileceğini düşündürüyor —
sistematik taranmadı.

**3. Dosya devliği**
| Dosya | Satır |
|---|---|
| `quiz_screen.dart` | 2224 |
| `profile_screen.dart` | 1861 |
| `quiz_result_screen.dart` | 1732 |
| `quiz/quiz_widgets.dart` | 1555 |
| `learning_screen.dart` | 1376 |
| `app_theme.dart` | 876 |

Bu boyuttaki dosyalarda tutarlılığı elle korumak zor; her "tasarım
denetimi" yeni sapma üretiyor çünkü kimse dosyanın tamamını tek seferde
gözden geçiremiyor.

**4. Görsel kanıt**
`docs/screenshots/phase2b/home_after.png` hâlâ metin-satırı-ağırlıklı bir
panel gösteriyor (sol sütun: yoğun düz metin satırları). Orijinal
2026-07-10 denetiminin "metin yığını" bulgusu kısmen sürüyor gibi görünüyor.

**5. Süreç artığı (çözüldü)**
`782a1a0` 16 adet tek-seferlik faz/denetim/hotfix raporunu (`PHASE_2E_*`,
`*_AUDIT.md`, `*_HOTFIX_REPORT.md` vb., 3385 satır) temizledi — bu zaten
kapanmış ama aynı üretim deseninin (çok sayıda ad-hoc rapor dosyası) tekrar
oluşmaması için Faz 4'te bir kural öneriliyor.

## Yaklaşım Seçimi

Üç yaklaşım değerlendirildi:

- **A — Önce yapısal (dosya bölme), sonra görsel.** Büyük dosyalar tek
  seferde bölünüp sonra görsel iş yapılır. Risk: canlıda çalışan joker/
  coin/matchmaking mantığına dokunan büyük, "sırf refactor için refactor"
  diff'ler; görünür fayda gecikir.
- **B — Agresif/paralel tam refactor.** Tüm ekranlar aynı anda ele alınır.
  Risk: geri bildirim döngüsü yok, regresyon riski yüksek, projenin
  kanıtlanmış "küçük paket, TDD" çalışma biçimine aykırı.
- **C — Önce görsel/tekrar temizliği, dosya bölme buna binerek
  (opportunistic).** **Seçilen yaklaşım.** Zaten değişen dosyalar küçültülür;
  sırf bölmek için dosyaya girilmez. Düşük risk, hızlı görünür sonuç,
  projenin var olan "Paket 0..6, küçük diff" deseniyle uyumlu.

## Plan — 5 Faz

### Faz 0 — Kararı sabitle
- Koyu-varsayılan + Bubblegum Arcade paleti (indigo/pembe/gökmavi/lime)
  **nihai karar** ilan edilir (kodun mevcut hâli, `fc6d2dd` sonrası).
- `bubblegum-arcade-redesign-design.md` içindeki "açık-öncelikli" bölümü
  kod gerçeğini yansıtacak şekilde güncellenir (tek satırlık not: "K1
  kararı `fc6d2dd` ile tekrar koyu-öncelikliye döndü, bu doküman artık
  yalnızca palet/bileşen kararları için geçerlidir").
- Süpersede edilmiş spec'ler (`kulturel-modern-2`, `best-in-class-experience`,
  `pirs-inspired-full-app-redesign`) `docs/superpowers/specs/_archive/`
  altına taşınır; aktif klasörde tek bir güncel tasarım yönü dokümanı kalır.

### Faz 1 — Tekrar/kopya avı
Ekran çiftleri sistematik taranır: `categories_tab.dart` / `subcategory_screen.dart`,
home kartları / `play_hub_screen.dart`, `leaderboard_screen.dart` /
`community_screen.dart`. Bulunan her tekrar birleştirilir ya da biri
diğerine yönlendiren teaser haline getirilir (Sereke/Bilîze düzeltmesindeki
desen).

### Faz 2 — Metin-yığını panelleri güzelleştir
Profil/mastery liste satırları, quiz sonuç metrik blokları hedeflenir. Düz
metin satırları, projenin zaten kurduğu görsel dile (kilim-desen filigran,
rozet, ilerleme halkası — `KilimPatternPainter`, mastery ring deseni)
taşınır.

### Faz 3 — Dev dosyaları böl (Faz 1-2'ye binerek)
Faz 1/2 için zaten açılan dosyalardan bağımsız widget'lar çıkarılır
(`quiz_screen.dart` → `screens/quiz/` altına, `profile_screen.dart` →
`screens/profile/` altına), mevcut `screens/home/`, `screens/quiz/` alt
klasör deseni genişletilerek.

### Faz 4 — Süreç kuralı (kalıcı)
CLAUDE.md'ye kısa bir kural eklenir: aynı anda yalnızca **bir** aktif "tam
uygulama yeniden tasarımı" spec'i olabilir; yenisi yazılmadan önce eskisi
kapatılır/süpersede edilir ve `_archive/`'a taşınır.

### Faz 5 — Canlı doğrulama
Kod tarafı tamamlandığında deploy edilir; kullanıcı `zankurd.com`'u kendi
tarayıcısında açıp (a) boş/donuk ekran olup olmadığını, (b) tema/paletin
beklendiği gibi göründüğünü teyit eder. Gerekirse CDN cache temizliği
yapılır (önceki oturumda karşılaşılmış bilinen bir sorun).

## Sınırlar

- Joker, coin, XP, matchmaking, mastery hesaplama mantığı değişmez —
  yalnızca sunum katmanı.
- Yeni paket eklenmez.
- Kurmancî/Türkçe dil seçimi ve mevcut test key'leri korunur.
- Faz 3'te dosya bölme, yalnızca zaten Faz 1/2 nedeniyle değişen dosyalarda
  yapılır; dokunulmayan dev dosyalar bu plan kapsamında bölünmez.

## Doğrulama

- Her faz sonunda `dart analyze` temiz geçer, ilgili `flutter test` paketi
  ve tam test paketi geçer.
- 360px ve 768px genişlikte taşma kontrolü.
- Light/dark mode karşılaştırması (artifact-design ilkesi: ikinci temaya
  aynı özen).
- Faz 5'te canlı doğrulama kullanıcı tarafından yapılır.
