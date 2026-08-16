import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'privacy manifest matches the current data inventory and no location API',
    () {
      final manifest = File(
        'ios/Runner/PrivacyInfo.xcprivacy',
      ).readAsStringSync();

      for (final dataType in [
        'NSPrivacyCollectedDataTypeUserID',
        'NSPrivacyCollectedDataTypeEmailAddress',
        'NSPrivacyCollectedDataTypeName',
        'NSPrivacyCollectedDataTypeEmailsOrTextMessages',
        'NSPrivacyCollectedDataTypeOtherUserContent',
        'NSPrivacyCollectedDataTypeGameplayContent',
        'NSPrivacyCollectedDataTypePhotosorVideos',
        'NSPrivacyCollectedDataTypeProductInteraction',
        'NSPrivacyCollectedDataTypeCrashData',
        'NSPrivacyCollectedDataTypePerformanceData',
        'NSPrivacyCollectedDataTypeDeviceID',
        'NSPrivacyCollectedDataTypePurchaseHistory',
      ]) {
        expect(manifest, contains(dataType));
      }

      expect(manifest, contains('<key>NSPrivacyTracking</key>\n\t<false/>'));
      expect(manifest, isNot(contains('NSPrivacyCollectedDataTypeLocation')));
      expect(manifest, isNot(contains('NSPrivacyAccessedAPICategoryLocation')));
    },
  );
}
