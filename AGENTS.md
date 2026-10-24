Bu proje Kürtçe soru çözme ve dahası için Flutter/Dart uygulamasıdır.

Çalışma kuralları:
- Türkçe cevap ver.
- Gereksiz uzun açıklama yapma.
- Git ve GitHub MCP kullanma.
- Onay beklemeden çalış; yalnız geri alınamaz ya da dışa dönük adımlarda (canlı veritabanı, mağaza yüklemesi, silme) önce sor.
- Büyük refactor yapma; küçük, güvenli ve test edilebilir adımlarla ilerle.
- Token tasarruflu çalış: sadece ilgili dosyaları incele, tüm projeyi gereksiz tarama.
- Kurmancî metinlerde yazım, karakter ve anlam doğruluğuna dikkat et.
- Uygulama modern, şık, profesyonel, çekici olmalı.

MCP kullanım kuralları:
- Dart MCP: Flutter/Dart analizi, runtime hata, widget inspector, pub ve proje araçları için kullan.
- Context7: Sadece güncel Flutter/Dart API, paket veya doküman kontrolü gerektiğinde kullan.
- Playwright: Sadece arayüzü gerçek ekranda kontrol etmek, taşma/buton/navigasyon hatası bakmak için kullan.
- Serena: Sembol bazlı kod analizi, class/fonksiyon/referans bulma ve güvenli refactor için kullan.
- Gereksiz MCP çağrısı yapma.

Test kuralları:
- Değişiklikten sonra önce dart analyze çalıştır.
- Gerekirse flutter test çalıştır.
- UI değişikliği varsa Flutter web veya uygun build üzerinden Playwright ile ekran kontrolü yap.
- Push'tan önce `zankurd_mobile/tool/ci_yerel.sh --tam` koştur; yalnız `flutter test` ya da hızlı `ci_yerel.sh` kırıkları kaçırdı (2026-09-30, 2026-10-15).
- Soru bankası (assets/data) değişince kalite kapısı parmak izi ister: `dart run tool/question_quality/question_quality_audit.dart baseline --accept-current-debt`; borç (blockers/criticals/issues) artmamalı.
- Sürüm (pubspec build numarası) yükselirse aynı commit'te `docs/app_review_packet_<sürüm>_build<no>.md` olmalı; bekçi test onu arar.

Canlı veritabanı (Supabase) kuralları:
- Uygulanan göçler `zankurd_mobile/supabase/applied.md`'de; uygulanınca satır ⏳ → ✅.
- Bir fonksiyonu değiştiren göçü ESKİ göç dosyasından değil CANLI tanımdan türet (`select pg_get_functiondef(...)`); birçok fonksiyon sonradan değişti (kalabalık oda, ödül havuzu, app_today, 1v1 canlılık) ve eski dosyadan kopyalamak bunları sessizce geri alır.
- Göçü uygulamadan önce canlı gövdeyle diff al; mümkünse `begin; … rollback;` içinde duman testi yap.
- Kurmancî içerikte toplu bul-değiştir yapma; yalnız denetlenmiş (id, alan) çiftlerini değiştir.
