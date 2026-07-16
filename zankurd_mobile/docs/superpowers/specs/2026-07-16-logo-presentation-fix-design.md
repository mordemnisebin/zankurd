# Logo Sunumu Düzeltmesi

**Tarih:** 2026-07-16

## Sorun ve kök neden

- `assets/zankurd.webp` 1254×1254 boyutunda ve tamamen opak beyaz zemine sahip.
- Splash arka planı kırık beyaz veya koyu olduğunda assetin kare sınırı görünür.
- Onboarding başlığında logo yüksek ekranda bile 68 px ile sınırlandığı için telefon ve masaüstünde küçük kalır.

## Değerlendirilen yaklaşımlar

1. **Önerilen: beyaz marka splash'i + responsive logo boyutu.** Splash her temada beyaz olur; assetin zemini kaybolur. Onboarding logosu mevcut `LayoutBuilder` eşiklerinde büyütülür. En küçük ve marka görselini bozmayan çözüm.
2. **Şeffaf yeni logo asseti üretmek.** Tema esnekliği sağlar ancak mevcut marka görselini yeniden işlemeyi ve yeni asset doğrulamasını gerektirir; bu hata için gereksiz risk.
3. **Logoyu belirgin bir karta çevirmek.** Kareyi gizler fakat kullanıcının rahatsız olduğu “ekrandan ayrı kutu” hissini güçlendirir.

## Onaylanan tasarım

- Splash ekranı açık/koyu tema ayrımı olmadan saf beyaz marka zemini kullanır.
- Splash logosunun mevcut merkez konumu, 280 px boyutu, animasyonu ve yükleme göstergesi korunur.
- Onboarding logosu normal telefon/masaüstü yüksekliğinde 96 px olur.
- 720 px altı yüksekliklerde başlık alanı 140 px, daha yüksek ekranlarda 180 px olur.
- Çok kısa yatay ekranlarda mevcut küçük boyut ve `FittedBox` koruması korunur; taşma riski alınmaz.
- Yeni paket, yeni widget veya yeni logo dosyası eklenmez.

## Doğrulama

- Splash açık ve koyu temada beyaz zemin testi.
- 390×844 ve 1200×800 onboarding logo boyutu testi.
- Mevcut yatay telefon taşma testi.
- `dart analyze`, ilgili widget testleri ve tam test paketi.
- Flutter web üzerinde 390 px telefon ve masaüstü Playwright ekran kontrolü.

