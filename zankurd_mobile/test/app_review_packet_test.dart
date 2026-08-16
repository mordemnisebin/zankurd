import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('App Review packet contains every Guideline 2.1 evidence section', () {
    final packet = File('docs/app_review_packet_1.9.2.md').readAsStringSync();

    for (final heading in [
      '## App Review Notes (copy/paste)',
      '## Core feature walkthrough',
      '## Account, deletion, and moderation',
      '## External services and data flows',
      '## Tested devices and release evidence',
      '## Regional behavior and third-party content',
      '## Owner inputs before resubmission',
    ]) {
      expect(packet, contains(heading));
    }

    expect(packet, contains('https://zankurd.com/privacy.html'));
    expect(packet, contains('https://zankurd.com/terms.html'));
    expect(packet, contains('https://zankurd.com/delete-account.html'));
    expect(packet, contains('https://zankurd.com/support.html'));
    expect(packet, contains('Supabase'));
    expect(packet, contains('RevenueCat'));
    expect(packet, contains('Firebase Crashlytics'));
    expect(packet, contains('iPhone 13 Pro'));
    expect(packet, contains('iOS 27.0 Beta'));
  });
}
