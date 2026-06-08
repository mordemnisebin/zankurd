# ZanKurd Multi-Platform Release Notes

Last updated: 2026-06-08

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

## Builds Verified On This Windows Machine

Android debug APK:

```powershell
flutter build apk --debug --dart-define=NEXT_PUBLIC_SUPABASE_URL=https://hupivnxgjtsfafulzspo.supabase.co --dart-define=NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY=sb_publishable_Hgs7VAhfNVmunE1siN2Lig_viLKqC2s
```

Output:

- `build/app/outputs/flutter-apk/app-debug.apk`

Web:

```powershell
flutter build web --dart-define=NEXT_PUBLIC_SUPABASE_URL=https://hupivnxgjtsfafulzspo.supabase.co --dart-define=NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY=sb_publishable_Hgs7VAhfNVmunE1siN2Lig_viLKqC2s
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
flutter build windows --dart-define=NEXT_PUBLIC_SUPABASE_URL=https://hupivnxgjtsfafulzspo.supabase.co --dart-define=NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY=sb_publishable_Hgs7VAhfNVmunE1siN2Lig_viLKqC2s
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
flutter build ipa --dart-define=NEXT_PUBLIC_SUPABASE_URL=https://hupivnxgjtsfafulzspo.supabase.co --dart-define=NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY=sb_publishable_Hgs7VAhfNVmunE1siN2Lig_viLKqC2s
```

macOS build command on macOS:

```bash
flutter build macos --dart-define=NEXT_PUBLIC_SUPABASE_URL=https://hupivnxgjtsfafulzspo.supabase.co --dart-define=NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY=sb_publishable_Hgs7VAhfNVmunE1siN2Lig_viLKqC2s
```

## Linux Requirement

Linux build should be run on Linux with GTK/CMake build dependencies installed.

Command:

```bash
flutter build linux --dart-define=NEXT_PUBLIC_SUPABASE_URL=https://hupivnxgjtsfafulzspo.supabase.co --dart-define=NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY=sb_publishable_Hgs7VAhfNVmunE1siN2Lig_viLKqC2s
```

## Store Release Tasks Still Needed

- Production app icon.
- Splash screen.
- Android release signing key.
- Google Play Console app listing.
- Apple Developer account.
- App Store Connect setup.
- Privacy policy URL.
- Terms of use URL.
- Screenshots for phone/tablet/web/desktop.
- Real profile login flow for production accounts.
- Admin content workflow for approving questions.
