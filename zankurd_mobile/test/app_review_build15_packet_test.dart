import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'build 15 App Review packet is marked as a candidate, not as approved',
    () {
      final packet = File(
        'docs/app_review_packet_1.9.2_build15.md',
      ).readAsStringSync();

      expect(packet, contains('ZanKurd iOS 1.9.2 (15)'));
      expect(packet, contains('App Privacy'));
      expect(packet, contains('https://zankurd.com/delete-account.html'));
      expect(packet, contains('RevenueCat'));
      expect(packet, contains('Report'));
      expect(packet, contains('Block'));
      expect(packet, contains('intentionally left blank'));
      expect(packet, contains('iOS 27.0 Beta'));
      expect(packet, isNot(contains('Binary State: Validated')));
    },
  );
}
