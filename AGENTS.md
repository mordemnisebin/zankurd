Bu proje Kürtçe soru çözme ve dahası için Flutter/Dart uygulamasıdır.

Çalışma kuralları:
- Türkçe cevap ver.
- Gereksiz uzun açıklama yapma.
- Git ve GitHub MCP kullanma.
- Dosya değiştirmeden önce kısa plan çıkar ve onay iste.
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