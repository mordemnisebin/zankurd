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

  test('leaderboard podium does not render a large empty pedestal block', () {
    final source = File(
      'lib/src/screens/leaderboard_screen.dart',
    ).readAsStringSync();

    expect(source, isNot(contains('height: height,')));
  });
}
