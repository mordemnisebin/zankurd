# KIMI3 — ZanKurd Web Performans Önerileri (kod değişikliği YOK, yalnızca analiz)

Tarih: 2026-07-19 · Dalga 3 raporu · Kaynak ölçümler: `docs/kimi3_notes/faz4_pirs_performans_erisilebilirlik.md` (canlı zankurd.com, brotli decode sonrası gerçek byte).

## Mevcut durum (ölçülen)

| Asset | Boyut (br) | Pay |
|---|---|---|
| `canvaskit.wasm` | 7,23 MB | ~%56 |
| `main.dart.js` | 4,93 MB | ~%38 |
| 4 × Rubik ağırlığı (Regular/Bold/Medium/Black) | ~700 KB | ~%5 |
| MaterialIcons-Regular.otf | 40 KB | — |
| `canvaskit.js` | 86,9 KB | — |
| **Toplam kritik ilk yük** | **~13 MB** | |

DOMContentLoaded ~0,4 sn; networkidle ~5 sn; cache'li reload `load` ~175 ms. Başarısız istek 0. Route geçişleri 2–2,5 sn (büyük olasılıkla her route'ta veri çekimi — 42 fetch).

## Seçenekler — risk/etki tablosu

| # | Seçenek | Beklenen etki | Risk | Efor | Not |
|---|---|---|---|---|---|
| 1 | **skwasm renderer** (`renderer: 'skwasm'` veya build'de `--web-renderer skwasm`) | canvaskit.wasm (7,2 MB) → skwasm ~1,1–1,5 MB wasm; **ilk yük ~%40–45 azalır** | Orta: multi-threaded skwasm `SharedArrayBuffer` ister (COOP/COEP header zorunlu; `htaccess_wasm_fix.zip` bu iş için hazırlanmış görünüyor). Header yoksa `forceSingleThreadedSkwasm: true` fallback gerekir → tek thread'de render performansı düşebilir. CanvasKit ile görsel parite %100 değil (ince farklar mümkün) | Düşük (build flag + sunucu header) | En yüksek kazanç/risk oranı. Flutter 3.44'te kararlı. Canlı sunucuda COOP/COEP header doğrulaması şart |
| 2 | **canvaskit `chromium` variantı** (`canvasKitVariant: 'chromium'`) | canvaskit daha küçük indirilir (yalnızca Chromium API'leri) | Yüksek: Safari/Firefox'ta kırılır — yalnızca Chromium-only kitle varsa | Çok düşük | ZanKurd genel web kitlesi → **önerilmez** |
| 3 | **Font subsetting + ağırlık azaltma** (Rubik Black kaldır, glyph subset) | ~700 KB → ~250–350 KB | Düşük: Black ağırlığı kullanan stiller Bold'a düşer (görsel fark minimal); Kurmancî karakterler (ê, î, û, ç, ş) subset'e dahil edilmeli — yanlış subset glyph kaybı yaratır | Orta (fonttools pyftsubset + pubspec güncelleme) | Güvenli, kalıcı kazanç. Önce Black kullanım sayısı grep ile doğrulanmalı |
| 4 | **Deferred components (split AOT)** | main.dart.js 4,9 MB → ilk paket küçülür; seyrek ekranlar (turnuva, hikâye, avatar editör) lazy | Yüksek: deferred import ağacı yeniden tasarımı, route'ları `deferred as` ile sarmalama, test güncellemeleri; hata durumunda beyaz ekran riski | Yüksek | Dalga kuralı gereği bu dalgada KOD YOK; ayrı fazda planlanmalı |
| 5 | **Cache stratejisi sıkılaştırma** (service worker + immutable asset header'ları) | Tekrar ziyaretlerde ağ yükü ~0 (zaten 175 ms reload) | Düşük: yanlış `Cache-Control` ile eski sürümde takılma riski; versiyonlu asset adları (flutter build zaten hash'liyor) bunu azaltır | Düşük | `.htaccess`/sunucu config; `flutter_service_worker.js` zaten var — `Cache-Control: public, max-age=31536000, immutable` yalnızca hash'li assetlere |
| 6 | **`--tree-shake-icons` doğrulaması** | MaterialIcons 40 KB → birkaç KB | Düşük: dinamik `IconData` kullanımı varsa ikon kaybı (testlerle yakalanır) | Çok düşük | Build komutuna eklenmeli; muhtemelen zaten açık — doğrulanmalı |
| 7 | **Route başına veri çekimini azaltma** (repository cache/optimistik geçiş) | Route geçişi 2–2,5 sn → anlık his | Orta: eski veri gösterme riski; cache invalidation mantığı gerekir | Orta-yüksek | Performans hissi asıl burada; ilk yük kadar önemli. Supabase sorgularının profili çıkarılmalı |

## Önerilen sıra

1. **skwasm denemesi** (staging'de, COOP/COEP header'larıyla) — tek hamlede ~5–6 MB kazanç.
2. **Font subsetting** (Rubik Black kaldır + Latin-ext subset) — risksiz ~350–450 KB.
3. **Cache header'ları** (immutable assetler) — tekrar ziyaretleri garanti altına alır.
4. **Route veri önbelleği** — geçiş sürelerini iyileştirir (ürün hissi açısından en görünür ikinci kazanç).
5. Deferred components — ayrı, planlı bir faz olarak (test yükü yüksek).

## Ölçüm planı (uygulandığında doğrulama)

- Aynı yöntem: taze context, network dinleme + API byte ölçümü (faz4 notlarındaki `perf_a11y_report*.json` kalıbı).
- Hedef: ilk yük ≤ 7 MB (skwasm + font subset ile ~6,5 MB gerçekçi), networkidle ≤ 3 sn, route geçişi ≤ 1 sn.
- Lighthouse a11y/perf skoru öncesi/sonrası kaydı.

> Bu dosya yalnızca analizdir; Dalga 3 kapsamında hiçbir performans kodu değiştirilmemiştir (dalga kuralı: riskli asset/bundle değişikliği YASAK).
