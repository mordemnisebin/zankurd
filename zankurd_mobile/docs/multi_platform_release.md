# ZanKurd Multi-Platform Release Notes

Last updated: 2026-08-02

> Güncel mağaza yayın sırası `docs/YAYIN_ADIMLARI.md` dosyasındadır. Bu belge
> platform derleme özeti olarak kullanılır; çelişki olursa yayın sırası esastır.

## Current Platform Status

ZanKurd is a Flutter app and now has platform folders for:

- Android
- iOS
- Web
- Windows
- macOS
- Linux

The shared Dart app code lives in `lib/`.

## App Identity

Public app name:

- ZanKurd

Bundle/application ID:

- `com.zankurd.app`

Dart package name:

- `zankurd_mobile`

The Dart package name intentionally remains lowercase with an underscore because Dart package names must follow that format.

## Platform Build Commands

Yerel, git tarafından yok sayılan yapılandırma dosyalarını önce depo
şablonlarından oluştur. Gerçek istemci anahtarlarını komut satırına veya bu
belgeye yazma.

Android debug APK:

```powershell
flutter build apk --debug --dart-define-from-file=.env.mobile.release.json
```

Output:

- `build/app/outputs/flutter-apk/app-debug.apk`

Web:

```powershell
flutter build web --release --no-web-resources-cdn --dart-define-from-file=.env.web.release.json
```

Output:

- `build/web`

## Windows Build

Windows build needs Windows Developer Mode enabled because Flutter plugins use symlinks.

Open:

```powershell
start ms-settings:developers
```

Enable:

- Developer Mode / Geliştirici Modu

Then run:

```powershell
flutter build windows --release --dart-define-from-file=.env.web.release.json
```

Expected output:

- `build/windows/x64/runner/Release/zankurd.exe`

This build has been verified on the current Windows machine after Developer Mode was enabled.

## iOS And macOS Requirement

iOS and macOS cannot be built directly on Windows because Apple requires Xcode on macOS.

Valid options:

- Build on a Mac with Xcode.
- Use a cloud macOS build service such as Codemagic or GitHub Actions macOS runners.

iOS build command on macOS:

```bash
flutter build ipa --release --dart-define-from-file=.env.mobile.release.json
```

macOS build command on macOS:

```bash
flutter build macos --release --dart-define-from-file=.env.mobile.release.json
```

## Linux Requirement

Linux build should be run on Linux with GTK/CMake build dependencies installed.

Command:

```bash
flutter build linux --release --dart-define-from-file=.env.web.release.json
```

## Store Release Tasks Still Needed

- Google Play Console app listing.
- Apple Developer account. Full Xcode required for iOS archive/upload
  (Command Line Tools alone is not enough).
- App Store Connect setup + RevenueCat subscription products.
- Privacy policy URL — `web/privacy.html` must be published at
  `AppConfig.privacyPolicyUrl` (https://www.zankurd.com/privacy.html).
- Terms of use URL — published at `AppConfig.termsOfServiceUrl`
  (https://www.zankurd.com/terms.html).
- Screenshots for phone/tablet/web/desktop.
- Real profile login flow for production accounts.
- Admin content workflow for approving questions.
