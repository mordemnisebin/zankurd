import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('iOS Firebase plist bundledır ve private credential içermez', () {
    final plist = File('ios/Runner/GoogleService-Info.plist');
    expect(plist.existsSync(), isTrue);

    final contents = plist.readAsStringSync();
    expect(contents, contains('<key>API_KEY</key>'));
    expect(contents, contains('<key>GCM_SENDER_ID</key>'));
    expect(contents, contains('<key>GOOGLE_APP_ID</key>'));
    expect(contents, contains('<key>BUNDLE_ID</key>'));
    expect(contents, contains('<string>com.zankurd.app</string>'));
    expect(contents, isNot(contains('PRIVATE_KEY')));
    expect(contents, isNot(contains('private_key')));
    expect(contents, isNot(contains('client_email')));
    expect(contents, isNot(contains('-----BEGIN')));

    final pbx = File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync();
    expect(pbx, contains('GoogleService-Info.plist in Resources'));
    expect(pbx, contains('path = "GoogleService-Info.plist";'));
  });

  test(
    'Debug development ve Release/Profile production entitlement kullanır',
    () {
      expect(
        File('ios/Runner/Runner.entitlements').readAsStringSync(),
        contains('<string>development</string>'),
      );
      expect(
        File('ios/Runner/Runner-Release.entitlements').readAsStringSync(),
        contains('<string>production</string>'),
      );
      final pbx = File(
        'ios/Runner.xcodeproj/project.pbxproj',
      ).readAsStringSync();
      expect(
        pbx,
        contains('CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;'),
      );
      expect(
        pbx,
        contains(
          'CODE_SIGN_ENTITLEMENTS = Runner/Runner-Release.entitlements;',
        ),
      );
    },
  );
}
