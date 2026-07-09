# ZanKurd Hostinger — final deploy checklist

Siteyi herkese atmadan önce bu listeyi uygula.

## 1) Temiz release build

```powershell
cd "C:\Users\AMARGİ\Desktop\pirs kurmanci\zankurd_mobile"
flutter clean
flutter pub get
dart analyze
flutter test --exclude-tags preview
flutter build web --release `
  --dart-define=SUPABASE_URL=https://SENIN-PROJE.supabase.co `
  --dart-define=SUPABASE_ANON_KEY=SENIN_ANON_KEY
```

> Not: `AppConfig` içinde default proje anahtarları da var; production’da yine de **kendi** `--dart-define` değerlerini kullan.

## 2) ZIP (önemli)

- Klasör: `build\web`
- ZIP’e **`build\web` klasörünün kendisini değil, içindeki dosyaları** koy:
  - `index.html`, `main.dart.js`, `flutter.js`, `assets/`, `canvaskit/`, `.htaccess`, …

PowerShell örneği:

```powershell
cd build\web
Compress-Archive -Path * -DestinationPath ..\..\zankurd_web_release.zip -Force
```

## 3) Hostinger yükleme

1. File Manager / FTP → public_html (veya domain root)
2. Eski dosyaları yedekle, yenileri yükle
3. `.htaccess` yüklü mü kontrol et (SPA 404 önler)
4. HTTPS açık olsun

## 4) 10 dakikalık smoke (yayın sonrası)

Telefon + bilgisayar tarayıcı:

1. Site açılıyor, logo/onboarding görünüyor  
2. Misafir giriş  
3. Solo / hızlı quiz bitir  
4. Kategori → seviye → quiz  
5. Oda kur + ikinci cihazda kodla katıl (mümkünse)  
6. 1vs1 eşleşme dene (queue açık mı)  
7. Profil, mağaza, liderlik, ayarlar  
8. Dil Ku/Tr, tema light/dark  

## 5) Bilinen dürüst sınırlar

| Özellik | Durum |
|---------|--------|
| Contest quiz başlatma | Bilinçli **Yakında** (ana menüde yok) |
| Turnuva | **Bot kupa** (etiketli) |
| Canlı multiplayer | Supabase + RPC canlıda doğru olmalı |

## 6) “Tamamdır” kriteri

- [ ] Analyze + test yeşil  
- [ ] Web release build bu checklist ile alındı  
- [ ] Smoke 1–8 geçti  
- [ ] İki gerçek kullanıcı oda veya 1v1 denedi  

Bunlar tamamsa: **paylaşılabilir v1.8 web**.
