# T10 — A üzerinde oturum yükseltme doğrulaması

2026-10-30. **Yerel native yükseltmede misafir oturumu korundu.** Canlı
Supabase kullanılmadı; auth yanıtları yalnız `127.0.0.1:55441` üzerindeki
yerel fixture'dan geldi. Uygulamanın normal `main.dart`, Supabase SDK,
SharedPreferences ve iOS kurulum yolları kullanıldı.

## Derlemeler ve yöntem

- A: `78303C59-3B69-405D-B753-328AD4E06548`; bundle: `com.zankurd.app`.
- Eski kaynak: `6bf868321d7d1a0ef2aff074b385d25ab7e57976`.
- Yeni taban: `77213626ec950fb09664e7c5e8198abae95d1941` + T10 çalışma
  ağacının 357 Dart dosyalık üretim kaynak kopyası.
- Kopyalama anında iki `lib/` ağacı dosya bazında SHA-256 ile birebir eşitti.
  [Kaynak manifesti](session_source_manifest.json) dosya SHA-256:
  `ed179a353d4f85d627cf7ba3fdc1e1c69f90e64427e4534be5be5176c8a94be2`.
- Son kaynak kontrolünde `src/screens/quiz_screen.dart` (sonraki sayaç
  temizliği) ve `src/l10n/strings.dart` (kullanılmayan eski kayıt alt başlığı
  anahtarının kaldırılması), `src/screens/story_screen.dart` (aynı içerik
  biçimini tekrarsız üretme) farklıydı. `main.dart`, `auth_provider.dart`,
  `sign_in_screen.dart`, `sign_up_screen.dart` ve `app_config.dart`
  doğrulanan native derlemeyle hâlâ birebir aynıydı.

Her iki derlemede aynı yerel değerler kullanıldı; aşağıdaki public değer
tamamen yapaydır, gerçek anahtar değildir. Hiçbir `.env*` veya anahtar
dosyası okunmadı.

```sh
python3 tool/t10_auth_upgrade_fixture.py
flutter build ios --simulator --debug --no-pub \
  --dart-define=APP_ENV=development \
  --dart-define=SUPABASE_URL=http://127.0.0.1:55441 \
  --dart-define=SUPABASE_ANON_KEY=sb_publishable_t10_local_only_000000000000 \
  --dart-define=USE_BUNDLED_SUPABASE_DEFAULTS=false
xcrun simctl install 78303C59-3B69-405D-B753-328AD4E06548 \
  build/ios/iphonesimulator/Runner.app
```

1. A'nın önceki uygulaması, data ve AppGroup içeriği içeriklerine bakılmadan
   opak olarak yedeklendi.
2. Eski derleme `simctl install` ile mevcut uygulamanın üzerine kuruldu.
   `Hemen oyna` üzerinden yalnız fixture'da anonim oturum oluşturuldu.
   Profilde `T10 Yerel Misafir / ZK-T10LOCAL` görüldü.
3. Uygulama durduruldu. Yeni derleme aynı komutla üzerine kuruldu;
   `uninstall` veya veri temizleme kullanılmadı.
4. Yeni uygulama giriş istemeden doğrudan `Günaydın, T10!` ana sayfasına
   açıldı. Aynı misafir profili görüldü.

## Sonuç ve kareler

[İstek ölçümleri](session_overlay_metrics.json): toplam **1 signup, 0
refresh**. Eski derlemede 22 istek vardı. Yükseltmeden sonraki **23/23**
istek aynı fixture oturumunu kullandı. Fixture yalnız eşleşme boolean'ını
kaydetti; header/token/gövde kaydetmedi.

| Eski 6bf86832 | Güncel T10 kaynak kopyası |
|---|---|
| [Ana sayfa](native/A_session_old_home.png) | [Ana sayfa, doğrudan açılış](native/A_session_current_home.png) |
| [Misafir profili](native/A_session_old_profile.png) | [Aynı misafir profili](native/A_session_current_profile.png) |

Kareler gözle karşılaştırıldı: görünen ad, oyuncu kodu ve misafir durumu
korundu. Ayrıca `auth_upgrade_persistence_t10_test.dart` gerçek Supabase
SDK'sını mock HTTP/preferences ile yeniden başlatır; ikinci signup olmadan
aynı anonim kullanıcıyı geri yüklediğini doğrular. Kayıt/T4 testleriyle
birlikte **51 test geçti**; `dart analyze` ve Dart MCP analizi temizdi.

## Kök değerlendirmesi ve sınır

`6bf86832 → 77213626` arasında `main.dart` auth başlatması,
`auth_provider.dart`, iOS bundle/entitlement ayarları ve bağımlılık kilidi
değişmemiştir. Alternatif eski SHA
`19c16ed7b43ce1f1168dd2867b9a8442444a1286` ile karşılaştırmada da storage
anahtarı/erişim grubu geçişi yoktur; ilgili değişiklikler analytics rızası,
presence ve SVG bağımlılığıdır.

Kilitli `supabase_flutter 2.17.2`, anonim oturumu Keychain yerine varsayılan
`SharedPreferencesLocalStorage` ile `sb-<sunucu hostunun ilk bölümü>-auth-token`
anahtarında saklar. Uygulama özel storage anahtarı vermiyor. T4 giriş ekranı
değişikliği bu saklama yolunu değiştirmiyor. Bu nedenle doğrulanmamış bir
auth/depolama düzeltmesi eklenmedi.

Tur6'daki A olayının gerçek nedeni **belirlenemedi**. Bu test aynı bundle ve
aynı sunucu yapılandırmasıyla iOS üzerine kurulum/yerel saklama yolunu
kanıtlar; canlı token iptali, süresi dolmuş token'ın gerçek sunucuda
yenilenmesi veya eski kurulumun derleme parametreleri hakkında kanıt
değildir. Farklı Supabase hostu storage ad alanını değiştirir; yapılandırmasız
çevrimdışı misafir ise yalnız bellekte tutulur. Bunlar kaynakta görülen
olası açıklamalardır, A olayının saptanmış nedeni değildir.

## A'nın geri yüklenmesi

Test sonunda önceki `.app` yeniden kuruldu. Yalnız A kapatılarak preference
cache'i durduruldu; test sonrası app-owned data/AppGroup içeriği ayrı opak
yedeğe **taşındı**, başlangıç yedekleri geri kopyalandı. iOS container
metadata'sı korundu; dosya silinmedi. A tekrar açıldı, ZanKurd çalıştırılmadı
(`launchctl` listesinde uygulama süreci yoktu). Yerel fixture sunucusu
durduruldu; 55441 portunda dinleyen süreç kalmadı. Canlı oturum doğrulaması
yasak gereği yapılmadı.
