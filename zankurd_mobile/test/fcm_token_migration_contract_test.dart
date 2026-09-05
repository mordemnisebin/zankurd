import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('FCM göçü token, kuyruk ve tetikleyiciyi birlikte kurar', () {
    final sql = File('supabase/2026-08-26_fcm_token.sql').readAsStringSync();
    expect(sql, contains('set_fcm_token'));
    expect(sql, contains('push_outbox'));
    expect(sql, contains('enqueue_friend_request_push'));
    expect(sql, contains('claim_push_outbox'));
    expect(sql, contains('revoke select (fcm_token)'));

    final worker = File('tool/send_push_outbox.py').readAsStringSync();
    expect(worker, contains('claim_push_outbox'));
    expect(worker, contains('GOOGLE_APPLICATION_CREDENTIALS'));
    expect(worker, contains('Sır yoksa çıkış kodu 2'));
  });

  test('iOS Debug development, Release/Profile production APNs kullanır', () {
    expect(
      File('ios/Runner/Runner.entitlements').readAsStringSync(),
      contains('<string>development</string>'),
    );
    expect(
      File('ios/Runner/Runner-Release.entitlements').readAsStringSync(),
      contains('<string>production</string>'),
    );
    final pbx = File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync();
    expect(
      pbx,
      contains('CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;'),
    );
    expect(
      pbx,
      contains('CODE_SIGN_ENTITLEMENTS = Runner/Runner-Release.entitlements;'),
    );
  });
}
