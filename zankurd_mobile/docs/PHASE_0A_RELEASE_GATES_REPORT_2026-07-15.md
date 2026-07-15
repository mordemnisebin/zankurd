# ZanKurd Faz 0A Teknik Yayın Kapıları Raporu — 2026-07-15

## 1. Başlangıç branch ve commit

- Audit worktree: `C:\src\zankurd_audit_2026-07-15`
- Başlangıç branch: `codex/full-product-audit-2026-07-15`
- Doğrulanmış temel commit: `f590566bc07cf46d5ea14d3db58ad20e96a0e1bb`
- Uygulama branch'i: `codex/phase0a-release-gates-2026-07-15`
- Uygulama branch'inin ayrıldığı audit commit'i: `7aa4dc9ce1b11c7960e8e82d4bd2dcaa968c6a8a`

## 2. Audit commit'i

`7aa4dc9 docs: add full product audit`

Bu commit yalnız tam ürün audit raporunu ve 41 audit ekran görüntüsünü içerir. Commit öncesinde metin ve PNG yapısı hassas veri açısından kontrol edildi. PNG ham verisindeki tek e-posta benzeri rastlantısal bayt dizisinin metadata olmadığı; dosyanın yalnız `IHDR`, `IDAT` ve `IEND` chunk'larından oluştuğu doğrulandı.

## 3. Faz 0A'da değişen dosyalar

Uygulama ve build kapısı değişiklikleri:

- `.github/workflows/flutter_ci.yml`
- `README.md`
- `analysis_options.yaml`
- `android/app/build.gradle.kts`
- `lib/src/screens/settings_screen.dart`
- `test/widget_test.dart`
- `widgetbook/pubspec.lock`

Audit teslimatları ayrıca `docs/ZANKURD_FULL_PRODUCT_AUDIT_2026-07-15.md` ve `docs/screenshots/full_product_audit/2026-07-15/` altında commitlenmiştir.

## 4. Analyzer sorununun kök nedeni

Widgetbook bağımsız bir Flutter paketidir: kendi `pubspec.yaml`, `analysis_options.yaml`, lock dosyası ve `widgetbook: 3.25.0` bağımlılığı vardır. Başlangıçta `widgetbook/.dart_tool/package_config.json` yoktu. Kök `dart analyze`, nested `widgetbook/lib/main.dart` dosyasını kök paketin package config'iyle tarıyor; bu nedenle `package:widgetbook/widgetbook.dart` çözümlenemiyor ve devamında 25 sembol hatası oluşuyordu.

Bağımsız paket içinde `flutter pub get` çalıştırıldıktan sonra `dart analyze` sıfır sorunla geçti. Bu, kullanılan Widgetbook API'lerinin sürümle uyumlu olduğunu ve 26 hatanın API uyumsuzluğu değil paket sınırı/bağımlılık hazırlığı sorunu olduğunu kanıtladı.

## 5. Widgetbook için uygulanan paket sınırı

- Kök `analysis_options.yaml` yalnız `widgetbook/**` dizisini kök analyzer kapsamından ayırır.
- `lib/**`, `test/**` veya uygulama kaynakları exclude edilmedi.
- Hata ignore edilmedi, severity düşürülmedi.
- CI kök uygulama ve Widgetbook için ayrı `flutter pub get` ve `dart analyze` adımları çalıştıracak şekilde güncellendi.
- README iki paketin yerel doğrulama komutlarını ayrı ayrı belgeler.
- Widgetbook lock dosyasındaki yerel ZanKurd sürümü `1.8.0+10` → `1.8.1+11` olarak güncellendi; yeni transitive `package_info_plus` girdileri lock'a işlendi.

## 6. Kök uygulama analyzer sonucu

Başlangıç: exit 1, yalnız `widgetbook/lib/main.dart` içinde 26 hata.

Son doğrulama:

```text
Analyzing zankurd_mobile...
No issues found!
```

Exit code: `0`.

## 7. Widgetbook analyzer sonucu

`widgetbook` dizininde `flutter pub get` başarılı oldu. Son doğrulama:

```text
Analyzing widgetbook...
No issues found!
```

Exit code: `0`. Widgetbook hataları gizlenmedi; bağımsız paket olarak gerçek bağımlılıklarıyla analiz edildi.

## 8. Android signing önceki davranışı

Ortamda `android/key.properties` ve release keystore yoktu. Eski Gradle yapılandırması bu durumda release build'e `signingConfigs.getByName("debug")` bağlıyordu.

RED kanıtı:

- `flutter build appbundle --release` exit `0` ile 64.5 MB AAB üretti.
- `jarsigner -verify -verbose -certs` signer bilgisini `C=US, O=Android, CN=Android Debug` olarak gösterdi.
- Bu, release adı taşıyan artifact'ın sessizce debug anahtarıyla imzalandığını doğruladı.

## 9. Android signing yeni davranışı

Release task istendiğinde Gradle şu kontrolleri yapar:

- `android/key.properties` mevcut mu?
- `storeFile`, `storePassword`, `keyAlias`, `keyPassword` boş olmayan değerler içeriyor mu?
- `storeFile` gerçek bir keystore dosyasına işaret ediyor mu?

Eksik/yanlış durumda mesaj beklenen alan adlarını, debug build alternatifini ve release build'in güvenlik nedeniyle durdurulduğunu açıklar. Secret değerleri loglanmaz. Release build hiçbir koşulda debug signing config'e bağlanmaz.

## 10. Debug build etkisi

Son doğrulama:

```text
flutter build apk --debug
√ Built build\app\outputs\flutter-apk\app-debug.apk
```

Exit code: `0`. Release fail-fast kontrolü debug task'ını etkilemedi.

## 11. Release negatif test sonucu

Son `flutter build appbundle --release` kontrollü olarak exit `1` verdi. Mesaj:

```text
Release signing configuration is missing or incomplete.
Expected android/key.properties with non-empty fields:
storeFile, storePassword, keyAlias, keyPassword.
Use a debug build for development.
The release build was stopped for security and will not fall back to debug signing.
```

Önceki RED testinden kalan yerel AAB'nin SHA-256 değeri, boyutu ve zaman damgası negatif test öncesi/sonrası aynı kaldı:

`416A2B110A3DF1068CD2D08E1D0A5860FCBB3B0E6D0595B5EEB962EB6DDFDB57`

Dolayısıyla fail-fast denemesi yeni release artifact üretmedi. Bu eski, ignored ve debug-imzalı yerel AAB kesinlikle yayın için kullanılmamalıdır.

## 12. Sürüm fallback önce/sonra

Önce:

- Esas sürüm `pubspec.yaml` içinde `1.8.1+11`.
- Hata fallback'i `SettingsScreen.appVersion = '1.8.0+10'`.

Sonra:

- Production esas kaynağı hâlâ `PackageInfo.fromPlatform()`.
- İkinci sabit sürüm numarası kaldırıldı.
- Metadata yüklenene kadar veya yükleme başarısızsa `—` gösteriliyor.
- Hata `ErrorReporter` ile kaydediliyor; ekran açık kalıyor.
- Opsiyonel loader sınırı yalnız davranışı deterministik test etmek için eklendi; normal çağrılar değişmedi.

## 13. Eklenen/güncellenen testler

`test/widget_test.dart` içine iki test eklendi:

1. Gerçek `version+buildNumber` değerinin hem light hem dark temada gösterilmesi.
2. PackageInfo hatasında ekranın çökmemesi, `Sürüm —` gösterilmesi ve `1.8.0+10` değerinin görünmemesi.

TDD RED sonucu, `SettingsScreen` içinde henüz `packageInfoLoader` parametresi olmadığı için beklenen compile başarısızlığıydı. Minimum loader sınırı ve nötr fallback eklendikten sonra iki test de GREEN geçti.

## 14. Test sayısı ve sonucu

Başlangıç: `549` test başarılı.

Son durum:

```text
01:19 +551: All tests passed!
```

Test sayısı iki yeni sürüm testi nedeniyle 549'dan 551'e yükseldi; açıklamasız düşüş yok.

## 15. Web build sonucu

`flutter build web` exit `0` ile 109.0 saniyede tamamlandı:

```text
√ Built build\web
Wasm dry run succeeded.
```

## 16. WASM build sonucu

`flutter build web --wasm` final doğrulamada temiz geçmedi.

- İlk deneme: native `wasm-opt` exit `-1073740791` ile çöktü.
- Kontrollü ikinci deneme: aynı optimize aşamasında exit `254`, `ParallelWaitError: FormatException: Invalid UTF-8 byte`.
- Standart web build'in WASM dry-run'ı başarılıydı.
- Analyzer veya Dart kaynak derleme hatası raporlanmadı.
- Audit başlangıcında aynı Flutter/Dart sürümüyle WASM build daha önce başarıyla tamamlanmıştı.

İki farklı native araç hatası sonrasında üçüncü deneme yapılmadı ve uygulama kodu değiştirilmedi. Bu, Windows Flutter 3.44.1 / Dart 3.12.1 `wasm-opt` toolchain riski olarak açık kalmaktadır.

## 17. Dokunulmayan logic-sensitive alanlar

Aşağıdakiler değiştirilmedi:

- Soru metinleri, offline soru bankası, Supabase kayıtları ve import dosyaları
- Duplicate/cevap dağılımı/karantina sistemi
- Günlük yarışma fallback'i ve solo/oda kimliği
- Quiz timer/timeout, matchmaking, room, contest ve reward mantığı
- Coin, XP, streak ve badge davranışları
- PWA service worker ve iOS PrivacyInfo
- Görsel tasarım, kontrast ve ekran hiyerarşisi

Faz 0A kaynak diff'inde bu alanlara ait dosya yoktur. Audit ekran görüntüsü adlarındaki `quiz`/`contest` kelimeleri yalnız önceki docs commit'ine aittir.

## 18. Açık kalan riskler

1. Tam `dart format --output=none --set-exit-if-changed lib test tool` kontrolü, Faz 0A öncesinden kalan 14 kapsam dışı dosya nedeniyle exit `1` verdi. Bunlar arasında Supabase, quiz ve matchmaking dosyaları bulunduğundan bu fazda düzeltilmedi. Çalışma ağacı değişmedi. Faz 0A'nın değiştirdiği iki Dart dosyasının dar format kontrolü exit `0` verdi.
2. Widgetbook `lib/main.dart` da mevcut format standardına göre değişiklik istiyor; davranış/analyzer düzeltmesi için gerekli olmadığından değiştirilmedi.
3. WASM build iki native toolchain hatasıyla başarısız; standart web build başarılı.
4. Gerçek release keystore olmadığından pozitif release signing artifact testi yapılmadı. Negatif fail-fast ve debug build doğrulandı.
5. Ön-testten kalan debug-imzalı AAB ignored build dizinindedir; deploy edilmemelidir.
6. Flutter build çıktısı bazı plugin'lerin eski Kotlin Gradle Plugin uygulama yönteminin gelecekte desteklenmeyeceği uyarısını verdi.

## 19. Commit listesi

Temel commit'ten sonra:

1. `7aa4dc9ce1b11c7960e8e82d4bd2dcaa968c6a8a docs: add full product audit`
2. `6b22bcef063e9282c42afc5f7261dd6cacb19f70 build: establish widgetbook analysis boundary`
3. `b14566dcc0d77cac957ff21a641f36f10203375a build: fail fast without release signing`
4. `477cac73373482ac9ecc1b47aa6190a10ca28e07 fix: remove stale version fallback`

Bu rapor ayrıca ayrı bir docs commit'i olarak eklenecektir.

## 20. `git status --short`

Rapor oluşturulmadan hemen önce audit worktree çıktısı boştu. Generated plugin dosyaları her Flutter komutundan sonra normal/stat/numstat ve `--ignore-space-at-eol` ile anlamsal olarak boş doğrulandı; yalnız kullanıcı tarafından izin verilen yedi dosyaya hedefli restore uygulandı.

Rapor commit'inden sonra final status yeniden kaydedilecektir.

## 21. Ana çalışma dizininin değişmeden kaldığının kanıtı

Ana checkout:

```text
branch: main
HEAD: f590566bc07cf46d5ea14d3db58ad20e96a0e1bb
 M macos/Flutter/GeneratedPluginRegistrant.swift
```

Ana çalışma dizininde `pub get`, analyze, test, build, restore, reset, stash, clean veya commit çalıştırılmadı.

## Sonuç

Üç hedef düzeltme uygulanmış ve odaklı kabul kriterleri karşılanmıştır: iki analyzer temiz, 551 test geçiyor, standart web build ve debug APK başarılı, release signing eksikken güvenli fail-fast çalışıyor, eski sürüm fallback'i kaldırıldı. Bununla birlikte tam format kapısı ve WASM build yeşil değildir; bu iki açık risk çözülmeden branch “tüm release doğrulamaları tamamen temiz” olarak tanımlanmamalıdır. Deploy, push, main merge, soru bankası veya Faz 1 işlemi yapılmadı.
