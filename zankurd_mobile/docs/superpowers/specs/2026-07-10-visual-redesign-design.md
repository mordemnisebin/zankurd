# Zankurd Görsel Tasarım Yükseltmesi — Tasarım Dokümanı

**Tarih:** 2026-07-10 · **Talep:** "Tasarımı benzeri uygulamalar kadar profesyonel, şık,
modern ve göze hitap eden, sadece metinle dolu olmayan bir biçime kavuştur."

## Denetim yöntemi

`build/web` (mock mod) yerel sunucuda açıldı; Playwright ile 420×900 mobil viewport'ta
onboarding → auth → home → kategoriler → alt-kategori → seviye → quiz → sonuç akışının
20 ekran görüntüsü alındı ve tek tek incelendi.

## Bulgular

**Güçlü:** auth ekranı, kategori illüstrasyonları, quick-play grid'i, leaderboard
podyumu, sonuç skor kartı — bunlara dokunulmaz.

**Zayıf (metin-dolu hissinin kaynakları):**
1. Varsayılan tema açık/krem; koyu header → krem gövde kopukluğu (brief: koyu ağırlıklı).
2. `subcategory_screen.dart`: düz beyaz metin satırları + büyük boş alan.
3. `level_screen.dart`: numaralı düz satırlar; ilerleme/kilit/ustalık görselliği yok.
4. Home görevler kartı: metin listesi, cılız progress.
5. Kategori kartında uzun başlık ("Paradigma") kırpılıyor.

## Kararlar

**K1 — Varsayılan tema koyu.** `ThemeProvider` kayıtlı tercih yoksa `ThemeMode.dark`
ile başlar (brief "koyu tema ağırlıklı" der; açık tema seçilebilir kalır). Tek satırlık
davranış değişikliği, tüm uygulamayı premium koyu kimliğe taşır ve home'daki
header/gövde kopukluğunu bitirir.

**K2 — Alt-kategori kartları.** Beyaz liste satırları yerine kategori renk kimliğini
taşıyan gradyan kartlar: büyük ikon rozeti, kilim deseni filigranı
(mevcut `KilimPatternPainter`), soru sayısı çipi. Navigasyon davranışı aynen korunur.

**K3 — Seviye yolculuğu.** Seviye satırları kademe-renkli, ilerleme halkalı
(CustomPaint ring), zorluk yıldızlı kartlara dönüşür. Route/parametreler değişmez.

**K4 — Görev kartı.** Görev tipi ikonları + gradyan dolgu progress barları +
ödül coin çipleri. Veri modeli değişmez.

**K5 — Kategori başlık kırpılması.** İki satır + otomatik küçülme (FittedBox değil,
maxLines: 2 + daha dengeli font).

## Yapılmayacaklar (YAGNI)

- Duolingo tarzı harita/yol ekranı (büyük yapısal iş, ayrı sprint).
- Yeni illüstrasyon üretimi (mevcut kategori görselleri yeterli).
- Navigasyon, route, state, repository değişikliği — sıfır.

## Doğrulama

Her adımdan sonra `dart analyze` + ilgili testler; sonunda tam paket +
`flutter build web --release` + Playwright ile aynı akışın yeniden ekran görüntüleri
(önce/sonra karşılaştırması). Görsel iddiaları test eden before/after testleri
bilinçli tasarım değişikliğiyle çelişirse test güncellenir ve raporda belirtilir.

## Sonuç (2026-07-10, uygulandı)

- K1–K5 uygulandı; `dart analyze` temiz, **373/373 test geçiyor**
  (`widget_test.dart` içindeki tema testi yeni sözleşmeye göre güncellendi,
  `theme_default_test.dart` sıfır-kurulum koyu açılışı kalıcı güvenceye aldı).
- Yeni build Playwright ile piksel düzeyinde doğrulandı: sıfır kurulumda
  onboarding arka planı R13,G39,B29 (AppTheme.bg koyu orman yeşili); home,
  alt-kategori ve seviye ekranları koyu kimlikte, kartlar renk/ikon/yıldız
  görselliğiyle. Önce/sonra görüntüleri: `docs/screenshots/redesign-2026-07/`.
