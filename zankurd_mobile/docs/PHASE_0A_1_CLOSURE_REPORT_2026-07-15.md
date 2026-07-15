# ZanKurd Faz 0A.1 Kapanış ve WASM Doğrulama Raporu — 2026-07-15

## 1. Branch ve başlangıç HEAD

- Worktree: `C:\src\zankurd_audit_2026-07-15`
- Uygulama kökü: `C:\src\zankurd_audit_2026-07-15\zankurd_mobile`
- Branch: `codex/phase0a-release-gates-2026-07-15`
- Doğrulanan başlangıç HEAD: `62044201ab5ae47c8d93dfbd099cd694430a81c2`
- Ön kontrollerde tracked ve staged diff boştu.

## 2. Eski AAB çıktıları ve kontrollü temizlik

Temizlikten önce iki ignored ve untracked build çıktısı doğrulandı:

1. `build\app\outputs\bundle\release\app-release.aab`
   - SHA-256: `416A2B110A3DF1068CD2D08E1D0A5860FCBB3B0E6D0595B5EEB962EB6DDFDB57`
   - Faz 0A RED testinden kalmış, debug anahtarıyla imzalı ve yayınlanamaz nihai çıktıydı.
2. `build\app\intermediates\intermediary_bundle\release\packageReleaseBundle\intermediary-bundle.aab`
   - SHA-256: `AFE48FC99C6FD25D2634B4E59182A6614F0389197928B6CB775AA57A10CAFC6C`
   - Gradle'ın paketleme sırasında oluşturduğu geçici ara build çıktısıydı.

İki dosyanın da `/build/` ignore kuralı kapsamında ve tracked olmadığı kanıtlandı. Her ikisi yalnız izole worktree'deki ignored `build` dizininden, uygulama kökünde bir kez çalıştırılan `flutter clean` ile kaldırıldı. `Remove-Item`, `git clean`, manuel taşıma veya repository dışı temizlik kullanılmadı. Temizlikten sonra `build` altında AAB sayısı sıfırdı. Hiçbir release artifact yayınlanmadı, kopyalanmadı veya deploy edilmedi.

## 3. Başlangıç ortamı

- Flutter: `3.44.1` stable, framework `924134a44c`
- Engine: `c416acfeb8`
- Dart: `3.12.1` stable, windows_x64
- DevTools: `2.57.0`
- Java: Eclipse Temurin OpenJDK `17.0.19+10`
- PowerShell: `7.6.3`
- İşletim sistemi: Windows 11 Pro `10.0.26200`, build `26200`
- Makine: HP Victus 16-r1xxx, 16,869,281,792 bayt RAM
- `flutter doctor -v`: sorun yok
- WASM koşularında `TMP` ve `TEMP`: `C:\src\tmp`

## 4. wasm-opt doğrulaması

- Araç: `C:\src\flutter\bin\cache\dart-sdk\bin\utils\wasm-opt.exe`
- Boyut: `9,063,936` bayt
- SHA-256: `FF2FB78FDAAB719111AFBAD6B976FF670326FA828600C155EF6D2058048519CE`
- Sürüm: `wasm-opt version 128 (58de22cdfd0ccb38ce68632695c0493c587af932)`

## 5. Güncel branch temiz WASM sonucu

İlk temiz doğrulama:

```text
flutter build web --wasm -v
exit: 0
Compiling lib\main.dart for the Web... 171.5s
√ Built build\web
```

İkinci bağımsız doğrulama öncesinde sırasıyla `flutter clean` ve `flutter pub get` çalıştırıldı:

```text
flutter build web --wasm
exit: 0
Compiling lib\main.dart for the Web... 108.9s
√ Built build\web
```

Her iki koşuda da WASM modülü ve JavaScript başlatıcı çıktısı üretildi.

## 6. Referans commit sonucu

`7aa4dc9ce1b11c7960e8e82d4bd2dcaa968c6a8a` için detached referans worktree oluşturulmadı ve referans build çalıştırılmadı. Talimattaki referans A/B koşulu yalnız güncel branch temiz koşusu başarısız olursa devreye girecekti. Güncel branch iki ardışık temiz koşuda başarılı olduğundan ek referans deneyi gereksizdi.

## 7. Log yolları

- Güncel branch verbose logu: `docs/audit/phase0a-current-wasm-build.log`
- Referans logu: oluşturulmadı; referans koşusu tetiklenmedi.

Güncel log; kullanıcı adı, özel kullanıcı profili yolu, e-posta, JWT, token, API anahtarı, parola ve secret kalıpları açısından tarandı; eşleşme bulunmadı.

## 8. Önceki WASM hata özeti

Faz 0A'daki önceki iki hata aynı native optimize aşamasında fakat farklı biçimde oluşmuştu:

1. `wasm-opt` exit `-1073740791` (`0xC0000409`)
2. exit `254` ve `ParallelWaitError: FormatException: Invalid UTF-8 byte`

Bu kapanışta aynı Flutter/Dart kaynakları ve araç sürümüyle iki temiz derleme arka arkaya geçti.

## 9. A/B/C/D sınıflandırması

**Durum C — önceki başarısızlık geçici native toolchain olayıdır.**

Güncel branch temiz koşuda başarılı olmuş, yeniden temizlenip bağımlılıklar hazırlandıktan sonra ikinci kez de başarılı olmuştur. Bu nedenle referans commit karşılaştırması tetiklenmemiştir.

## 10. Kod regresyonu kanıtlandı mı?

Hayır. Uygulama kaynak koduna ait deterministik bir WASM regresyonu kanıtlanmadı. Önceki iki native araç hatası bu kapanışta tekrarlanamadı.

## 11. Faz 0A kabul durumu

Faz 0A'nın teknik yayın kapıları, WASM riski açısından kapanmıştır. Release signing pozitif artifact doğrulaması gerçek release keystore olmadığı için hâlâ kapsam dışıdır; güvenli negatif fail-fast kapısı doğrulanmıştır. Push, merge veya deploy yapılmamıştır.

## 12. Dar format kontrolü

```text
dart format --output=none --set-exit-if-changed lib/src/screens/settings_screen.dart test/widget_test.dart
Formatted 2 files (0 changed)
exit: 0
```

## 13. Önceden mevcut 14 format borcu dosyası

Tam format kapısında önceden mevcut ve Faz 0A kapsamı dışında kalan dosyalar değiştirilmedi:

- `lib/src/data/daily_mission_store.dart`
- `lib/src/data/supabase_zankurd_repository.dart`
- `lib/src/providers/theme_provider.dart`
- `lib/src/screens/learning_screen.dart`
- `lib/src/screens/matchmaking_screen.dart`
- `lib/src/screens/quiz/quiz_widgets.dart`
- `lib/src/screens/quiz_screen.dart`
- `lib/src/screens/tournament_screen.dart`
- `test/error_reporting_contract_test.dart`
- `test/matchmaking_screen_test.dart`
- `test/onboarding_hierarchy_test.dart`
- `test/speed_score_test.dart`
- `test/supabase_repository_test.dart`
- `test/tournament_screen_test.dart`

## 14. Kök analyzer

Faz 0A doğrulaması: `dart analyze` exit `0`, `No issues found!`

## 15. Widgetbook analyzer

Faz 0A doğrulaması: bağımsız Widgetbook paketinde `dart analyze` exit `0`, `No issues found!`

## 16. Test paketi

Faz 0A doğrulaması: `551` test başarılı, `All tests passed!`

## 17. Standart web build

Faz 0A doğrulaması: `flutter build web` exit `0`, standart web build ve WASM dry-run başarılı.

## 18. Debug APK

Faz 0A doğrulaması: `flutter build apk --debug` exit `0`; `app-debug.apk` başarıyla üretildi.

## 19. Release negatif testi

`flutter build appbundle --release`, gerçek release signing yapılandırması yokken beklenen biçimde exit `1` verdi. Mesaj eksik `storeFile`, `storePassword`, `keyAlias` ve `keyPassword` alanlarını belirtti; debug signing fallback'i yapılmadı ve yeni AAB üretilmedi.

## 20. Audit worktree durumu

WASM doğrulamalarından sonra yalnız aynı yedi generated plugin dosyası LF/CRLF nedeniyle modified göründü. Normal diff stat ve numstat boştu; `git diff --ignore-space-at-eol --exit-code` başarılıydı. Yalnız bu yedi dosyaya hedefli restore uygulandı. Kapanış raporu ve onaylı log dışında uygulama kodu değişmedi.

## 21. Ana checkout kanıtı

```text
branch: main
HEAD: f590566bc07cf46d5ea14d3db58ad20e96a0e1bb
 M macos/Flutter/GeneratedPluginRegistrant.swift
```

Ana checkout'ta build, test, clean, restore, stash, reset veya commit çalıştırılmadı.

## 22. Referans worktree durumu

`C:\src\zankurd_wasm_reference_2026-07-15` mevcut değildir. Durum C oluştuğu için oluşturulmamıştır; dolayısıyla kaldırılacak referans worktree yoktur.

## 23. Sonraki adım

Faz 0A.1 kapanış commit'i branch üzerinde yerel tutulmalıdır. Kullanıcı onayı olmadan push, merge, deploy, release artifact üretimi veya Faz 1 değişikliği yapılmamalıdır.

## Kapanış

İki eski AAB yalnız izole ignored build alanından `flutter clean` ile kaldırıldı. Güncel branch iki ardışık temiz WASM build'inde başarılı oldu; önceki hatalar geçici native toolchain olayı olarak sınıflandırıldı ve kod regresyonu kanıtlanmadı. Uygulama kodu, ana checkout ve canlı sistem değiştirilmedi.
