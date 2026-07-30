# ZanKurd Hostinger — final deploy checklist

Siteyi herkese atmadan önce bu listeyi uygula.

## 0) Yasal sayfalar (mağaza şartı)

Uygulama, Ayarlar ve paywall ekranlarında iki bağlantı gösteriyor ve bu
adları bekliyor — dosya adı tutmazsa bağlantı 404 verir:

| Depodaki dosya | Siteye yüklenecek ad |
|---|---|
| `web/privacy.html` | `privacy.html` |
| `web/terms.html` | `terms.html` |
| `web/delete-account.html` | `delete-account.html` |

Üçü de sitenin kökünde olmalı: `https://www.zankurd.com/privacy.html`,
`.../terms.html` ve `.../delete-account.html`. İlk ikisi `AppConfig.privacyPolicyUrl` /
`termsOfServiceUrl` ile birebir aynı olmalı.

Niçin ilk sıraya kondu: App Store, otomatik yenilenen abonelik satan
uygulamalarda kullanım koşulu bağlantısını şart koşar ve inceleyen kişi
bağlantıya tıklar. `terms.html` 2026-07-27'ye kadar hiç yazılmamıştı;
uygulama var olmayan bir sayfaya bağlantı veriyordu.

## 1) Tek komutlu doğrulanmış release

```bash
cd /Users/kocer/Projects/zankurd/zankurd_mobile
./release_web.sh
```

Komut `dart analyze`, bütün `flutter test` paketi ve açık yapılandırmalı
release derlemeyi tamamlamadan aktarım yapmaz. `.env.web.release.json`
yalnız herkese açık Supabase URL/publishable anahtarını taşır; servis rolü
veya parola konmaz.

## 2) Şifreli aktarım

`deploy_sftp.sh`, özel SSH anahtarı ve sabitlenmiş host key kullanır.
Önce `--dry-run` ile hedefin gerçek yolunu denetler; gerçek aktarımda
değiştirilen eski dosyaları web kökü dışına yedekler. `.htaccess` dahil
zorunlu dosyalardan biri eksikse durur.

### Wasm MIME tuzağı (2026-07-10)

`flutter build web --wasm` sonrası Hostinger bazen şunları `text/plain` verir:
- `main.dart.wasm` → olmalı **`application/wasm`**
- `main.dart.mjs` → olmalı **`text/javascript`**

Yanlış MIME = boş ekran + konsol: *Expected a JavaScript-or-Wasm module script*.

Çözüm: `web/.htaccess` (build’e kopyalanır) içinde `AddType` + `Header set Content-Type`.
Sadece `.htaccess` güncelleyip yeniden yüklemek genelde yeter.

Kontrol (PowerShell):
```powershell
(Invoke-WebRequest https://www.zankurd.com/main.dart.wasm -Method Head).Headers['Content-Type']
# beklenen: application/wasm
```

MIME düzelmezse Hostinger hPanel → MIME Types’tan elle ekle, veya Wasm’siz yedek:
```powershell
flutter build web --release --no-web-resources-cdn
```

## 3) 10 dakikalık smoke (yayın sonrası)

Telefon + bilgisayar tarayıcı:

1. Site açılıyor, logo/onboarding görünüyor  
2. Misafir giriş  
3. Solo / hızlı quiz bitir  
4. Kategori → seviye → quiz  
5. Oda kur + ikinci cihazda kodla katıl (mümkünse)  
6. 1vs1 eşleşme dene (queue açık mı)  
7. Profil, mağaza, liderlik, ayarlar  
8. Dil Ku/Tr, tema light/dark  

## 4) Bilinen dürüst sınırlar

| Özellik | Durum |
|---------|--------|
| Günlük etkinlik | **Aktif** — 10 soruluk ilerleme etkinliği; özel ödül ve sıralama yok |
| Turnuva | **Gerçek oyuncu kupası** |
| Canlı multiplayer | Supabase + RPC canlıda doğru olmalı |

## 5) “Tamamdır” kriteri

- [ ] Analyze + test yeşil  
- [ ] `./release_web.sh` eksiksiz tamamlandı
- [ ] Smoke 1–8 geçti  
- [ ] İki gerçek kullanıcı oda veya 1v1 denedi  

Bunlar tamamsa: **paylaşılabilir web sürümü**. (Sürüm numarası tek yerde
durur: `pubspec.yaml`. Buraya kopyalanmaz — kopyası eskir.)
