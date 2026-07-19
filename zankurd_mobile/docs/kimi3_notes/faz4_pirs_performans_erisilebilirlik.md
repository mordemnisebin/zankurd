# Faz 4 — Pirs Karşılaştırması, Performans & Erişilebilirlik (2026-07-19)

Canlı: https://zankurd.com/ — Viewport 390×844, kalıcı profil (misafir oturumlu), Playwright chromium.
Screenshotlar: `output/kimi3_live_visual_audit/2026-07-19/` (400–436).
Ham ölçüm JSON'ları: `perf_a11y_report*.json` aynı kökte.

---

## Aşama 20 — Pirs'ten Alınabilecek Ürün İlkeleri

Kaynaklar: Google Play sayfası (kurdi.leyzok.pirs, 4.8★, 1.7K yorum, 10K+ indirme), `Pirs_apk_extracted/reports/APK_ANALYSIS_SUMMARY_TR.md`, `pirs_home.png`, mağaza açıklaması/yorumları.

| # | Pirs ürün ilkesi | ZanKurd'daki karşılığı | Katkı | Karar | Gerekçe |
|---|---|---|---|---|---|
| 1 | Seviye sistemi (5 ast / level progression, `LevelActivity`, `quiz_level.db`) | Var: kategori → alt kategori → 5 ast | İlerleme hissi, geri dönüş motivasyonu | **Alındı / mevcut** — güçlendir | Pirs'in çekirdek tutma (retention) mekaniği; ZanKurd'da progressbar görünüyor ama ilerleme hep "0" — ilerleme kaydının görünür çalışması şart |
| 2 | Öğrenme alanı (LearningZone: önce oku/izle, sonra soru çöz) | Yok | Eğitim değeri, "öğren → pekiştir" döngüsü | **Doğrudan alınmalı (uyarlanarak)** | Pirs mağaza metninde öne çıkan fark; ZanKurd "Hîn bibe" onboarding'inde vaat ediyor ama üründe öğrenme modu yok. Kurmancî eğitim misyonuyla birebir örtüşür |
| 3 | Yer işareti / yanlış tekrarı (BookmarkList, BookmarkPlay, `quiz_bookmark.db`) | Yok | Kişisel tekrar, zayıf nokta çalışması | **Doğrudan alınmalı** | Ucuz, yüksek değerli öğrenme özelliği; yanlış soruları biriktirip tekrar oynatma |
| 4 | Oda açma + kodla katılma + rastgele eşleşme | Var (Oda Kur / Kodla Katıl / Rastgele) | Sosyal rekabet | **Mevcut — alınacak bir şey yok** | ZanKurd bu ilkeyi zaten uyguluyor |
| 5 | Jokerler: Çift Cevap, Seyirciye Sor, Soru Değiştir, %50 | Kısmen var (50/50, Seyirci) | Oyun derinliği | **Uyarlanmalı** | "Soru Değiştir" ve "Çift Cevap" eklenebilir; ama coin ekonomisiyle dengeli olmalı |
| 6 | Günlük/aylık kazananlar listesi (günün/ayın kazananları) | Var (Rêz tabı, liderlik) | Rekabet motivasyonu | **Mevcut** | Pirs: "winners of the day, of the month" — ZanKurd'da karşılığı var |
| 7 | Turnuva / yarışma takvimi (ContestActivity, geçmiş + planlanan yarışmalar) | Var (Pêşbazî / turnuva) | Planlı etkinlik, geri dönüş | **Mevcut — güçlendir** | Pirs'te geçmiş yarışma arşivi + gelecek takvim ayrımı net; ZanKurd'a "geçmiş turnuvalar + kazananlar" görünürlüğü eklenebilir |
| 8 | Spin wheel / ödül çarkı, coin mağazası, IAP | Var (çerx/spinwheel tur ekranlarında) | Monetizasyon + günlük dönüş | **Mevcut** | Alınacak ilke yok |
| 9 | Matematik modu (MathsPlay, MathJax ile formül render) | Yok | Kategori genişlemesi | **Alınmamalı (şimdilik)** | ZanKurd'un odağı Kurmancî dil/kültür; matematik odak dışı, MathJax yükü performans maliyeti |
| 10 | Bildirimle "yeni güncel sorular" duyurusu (FCM) | Yok (web) | Re-engagement | **Uyarlanmalı** | Web push ile günlük soru / turnuva hatırlatması düşünülebilir; Pirs bunu mağaza metninde satış argümanı yapıyor |
| 11 | Reklam (AdMob + Facebook Audience Network) | Yok | Gelir | **Alınmamalı** | ZanKurd web'de premium his hedefleniyor; Pirs yorumlarında reklam şikayeti görülmemiş ama reklam yoğunluğu marka algısına risk |
| 12 | Robotla oynama (RobotPlayActivity — beklemede bot) | Belirsiz (1v1 bekleme ekranları var) | Boş odaya karşı garanti oyun | **Uyarlanmalı** | Canlı rakip bulunamayınca bot/rakip simülasyonu churn'ü azaltır; Pirs bunu çözmüş |
| 13 | Talimat/öğretici ekranı (InstructionActivity) | Kısmen (onboarding "Hîn bibe") | İlk açılış yönlendirmesi | **Mevcut — yeterli** | — |

Not: Görsel dil (Pirs'in mor/pembe teması, logo) kopyalanmayacak; tablo sadece ürün ilkeleri.

---

## Aşama 22 — Performans Ölçümleri (kanıtlı)

Yöntem: taze context, network dinleme + API GET ile gerçek byte ölçümü. Başarısız istek: **0** (48 istek, tümü <400).

### İlk yükleme
| Metrik | Değer |
|---|---|
| DOMContentLoaded | ~393 ms |
| Ağ sakinleşme (networkidle, yaklaşık) | ~5,0 sn |
| Ana sayfa etkileşime hazır (splash sonrası, semantik ağaç oluşumu) | ~3,1 sn |
| Reload `load` event | ~175 ms (cache'li) |
| Toplam istek sayısı | 48 (1 document, 5 script, 42 fetch) |

### Asset boyutları (brotli ile sunulan, ölçülen decoded/gerçek byte)
| Asset | Boyut |
|---|---|
| `main.dart.js` | **4,93 MB** (br) |
| `canvaskit.wasm` | **7,23 MB** (br) |
| `canvaskit.js` | 86,9 KB |
| Rubik-Regular.ttf | 175 KB |
| Rubik-Bold.ttf | 176 KB |
| Rubik-Medium.ttf | 176 KB |
| Rubik-Black.ttf | 175 KB |
| MaterialIcons-Regular.otf | 40 KB |
| **Toplam kritik yük (yaklaşık)** | **~13 MB** |

### Route geçişleri (yaklaşık, kronometre)
| Geçiş | Süre |
|---|---|
| Ana sayfa → Kategorî (tab tık) | ~2,0 sn |
| Kategorî → alt kategori ("Ziman" kartı) | ~2,5 sn |
| Alt kategori listesi anında semantik ağaçta | buton rolleriyle geliyor |

### Performans bulguları
- **P1 — İlk yük ~13 MB**: `canvaskit.wasm` 7,2 MB + `main.dart.js` 4,9 MB. Mobil bağlantıda ilk açılış 5 sn üstü. Öneri: HTML renderer veya canvaskit lite değerlendirmesi, deferred loading, tree-shaking doğrulaması (`--tree-shake-icons`), font subsetting.
- **P2 — 4 ayrı Rubik ağırlığı (~700 KB)**: Black ağırlığı muhtemelen seyrek kullanılıyor; subset + daha az ağırlık yeterli.
- **P2 — Route geçişleri 2–2,5 sn**: SPA içi geçişlerde hissedilir gecikme; büyük olasılıkla her route'ta veri çekimi (42 fetch isteği). Önbellek/optimistik geçiş değerlendirilebilir.
- **Olumlu**: Başarısız istek yok; fontlar ve JS brotli sıkıştırmalı sunuluyor; cache'li reload hızlı (175 ms).

---

## Aşama 23 — Erişilebilirlik

### Flutter web semantics
- İlk açılışta semantik ağaç **kapalı**: `flt-semantics` node sayısı 0, ekranda sadece "Enable accessibility" butonu var (1×1 px, viewport dışı koordinatlı — fareyle tıklanamıyor, JS ile tıklanabildi).
- JS ile etkinleştirince 40 semantik node oluştu ve anlamlı aria ağacı çıktı: butonlar ("Ziman", "Tema", "Destpêk bike", "Hemûyê bibîne"), tablist (Sereke/Kategorî/Pêşbazî/Rêz/Profîl), progressbar'lar. → semantik altyapı doğru kurulmuş.
- **P1 bulgu**: "Enable accessibility" butonu klavye/fareyle ulaşılamaz konumda; ekran okuyucu kullanıcısı semantiği açamazsa sayfa tamamen boş görünür. Flutter web'de `auto` semantics (ve/veya `flutter_bootstrap.js` ile `SemanticsBinding` otomatik etkinleştirme) değerlendirilmeli.

### Tab sırası & görünür focus (semantik açıkken)
- Sıra: FLUTTER-VIEW (2 ölü durak) → "Destpêk bike" → "Zû bilîze" → tab'lar (Sereke→Kategorî→Pêşbazî→Rêz→Profîl) → BODY. Mantıklı sıra.
- **P2 bulgu**: Focus göstergesi `outline: auto 1px` — çok ince; 390px mobilde ve düşük kontrastlı zeminde zor görünür. 2–3 px belirgin focus halkası önerilir.
- **P3 bulgu**: İlk 2 Tab "FLUTTER-VIEW" boş durağına gidiyor (ölü focus stop).

### Rol/etiket sorunları
- **P1 bulgu**: Kategori kartları (`Ziman 1083 pirs • 5 ast` vb.) `group` rolünde, `button` değil — ekran okuyucu bunların tıklanabilir olduğunu söylemiyor. Alt kategori ekranındaki kartlar doğru şekilde `button` rolünde. Kategori kartlarına `button`/link semantiği eklenmeli.
- **P2 bulgu**: Birçok `flt-semantics[role="button"]` öğesinde `aria-label` null (metin child'dan geliyor); çoğu okunuyor ama üst bar ikon butonları (Ziman/Tema butonları dışındaki 44×44 ikonlar) etiketsiz görünüyor.

### Dokunma hedefleri (ölçülen)
| Hedef | Boyut |
|---|---|
| Üst bar ikon butonları | 44×44 ✓ |
| "Destpêk bike" kartı | 110×94 ✓ |
| İlerleme/misyon satırı | 316×32 ✗ (yükseklik <44) |
| "Zû bilîze" kartı | 350×118 ✓ |
| "Hemûyê bibîne ›" | 102×17 ✗✗ (çok küçük) |
- **P1 bulgu**: "Hemûyê bibîne ›" (102×17 px) ve misyon satırı (32 px yükseklik) 44px kuralının altında.

### Zoom %200
- `document.body.style.zoom=2.0` ile: yatay kaydırma **yok** (scrollWidth 390 = viewport), layout bozulmadı (screenshot 412). ✓ Olumlu.
- Tarayıcı zoom yerine CSS zoom testi yapıldı (headless'ta native zoom yok); gerçek tarayıcı zoom'unda canvas tabanlı render genelde sorunsuz ölçeklenir ama cihazda doğrulanmalı.

### Kontrast (spot)
- Flutter web canvas render ettiği için DOM computed style üzerinden renk ölçülemedi (tüm node'lar `rgba(0,0,0,0)` döndü). → **Sınırlama**: kontrast yalnızca görsel screenshot üzerinden değerlendirilebilir; light tema screenshot'larında (434) başlık/metin kontrastı görsel olarak yeterli görünüyor, kesin oran ölçümü yapılamadı.
- Dark tema: `color_scheme=dark` emülasyonunda `body` arka planı `rgba(0,0,0,0)` ve ekran içeriği canvas'ta kaldı (screenshot 415); uygulama `prefers-color-scheme`'e göre tema değiştirmiyor gibi — "Tema" butonu uygulama içi. Doğrulama sınırlı.

### Sınırlamalar
- Ekran okuyucu (NVDA/VoiceOver) testi **yapılamadı** — yalnızca aria ağacı üzerinden çıkarım.
- Kontrast oranları sayısal ölçülemedi (canvas render).
- "Enable accessibility" butonu yalnızca JS ile tıklanabildi; gerçek kullanıcı davranışı doğrulanmadı.

---

## Öncelik özeti
- **P0**: (yok — sayfa çalışıyor, kritik kırık bulunmadı)
- **P1**: Semantics varsayılan kapalı + "Enable accessibility" butonuna klavye/fare erişilemez; kategori kartları button rolünde değil; ~13 MB ilk yük; "Hemûyê bibîne ›" 17 px dokunma hedefi.
- **P2**: İnce focus halkası (1px); route geçişleri 2–2,5 sn; 4 Rubik ağırlığı; bazı ikon butonlarda aria-label eksik.
- **P3**: Ölü Tab durakları (FLUTTER-VIEW); dark tema sistem tercihine otomatik yanıt yok gibi.
