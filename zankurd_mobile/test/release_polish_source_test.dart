import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/providers/auth_provider.dart';

void main() {
  test('mobile auth redirect is app deep link and never localhost', () {
    expect(AuthProvider.authRedirectUri, 'com.zankurd.app://login-callback/');
    expect(AuthProvider.authRedirectUri, isNot(contains('localhost')));
  });

  test('Android manifest handles the Supabase login deep link', () {
    final source = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    expect(source, contains('android:scheme="com.zankurd.app"'));
    expect(source, contains('android:host="login-callback"'));
  });

  test('daily reminders avoid exact alarm Play policy risk', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    final notificationService = File(
      'lib/src/services/notification_service.dart',
    ).readAsStringSync();

    expect(manifest, isNot(contains('SCHEDULE_EXACT_ALARM')));
    expect(
      notificationService,
      contains('AndroidScheduleMode.inexactAllowWhileIdle'),
    );
    expect(
      notificationService,
      isNot(contains('AndroidScheduleMode.exactAllowWhileIdle')),
    );
  });

  test('iOS declares the photo-library reason used by avatar editing', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();

    expect(plist, contains('<key>NSPhotoLibraryUsageDescription</key>'));
    expect(plist, contains('profil fotoğrafınızı seçebilmek'));
  });

  test('iOS declares export compliance so uploads need no manual answer', () {
    // Anahtar yoksa App Store Connect her yüklemede "şifreleme kullanıyor
    // musunuz?" diye sorar ve yanıtlanana kadar build "Missing Compliance"
    // durumunda bekler. Yani eksikliği bir hata vermez — yalnız her
    // sürümde elle bir adım ekler ve o adım unutulursa build yayına
    // çıkmaz (2026-07-27).
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    expect(plist, contains('ITSAppUsesNonExemptEncryption'));
  });

  test('iOS declares both interface languages for the store listing', () {
    // App Store liste sayfasındaki "Diller" satırı bu anahtardan üretilir.
    // Anahtar yokken yalnız geliştirme dili görünür — iki dilli bir
    // uygulama için mağazada yanlış bilgi demektir.
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    expect(plist, contains('CFBundleLocalizations'));
    for (final code in const ['ku', 'tr']) {
      expect(
        plist,
        contains('<string>$code</string>'),
        reason: '$code dili beyan edilmemiş',
      );
    }
  });

  test('app preserves the supported 200 percent system text scale', () {
    final source = File('lib/main.dart').readAsStringSync();

    expect(source, contains('maxScaleFactor: 2.0'));
    expect(source, isNot(contains('maxScaleFactor: 1.35')));
  });

  test('app shell mounts expensive tabs only after first visit', () {
    final source = File('lib/src/screens/app_shell.dart').readAsStringSync();

    expect(source, contains('final Set<int> _visitedTabs = {0};'));
    expect(source, contains('_visitedTabs.add(i)'));
    expect(source, contains('_visitedTabs.contains(index)'));
  });

  test('leaderboard podium does not render a large empty pedestal block', () {
    final source = File(
      'lib/src/screens/leaderboard_screen.dart',
    ).readAsStringSync();

    expect(source, isNot(contains('height: height,')));
  });
}
