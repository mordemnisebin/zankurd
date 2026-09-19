import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import '../tool/validate_device_release_evidence.dart';

void main() {
  const version = '1.9.2+20';
  const sourceFingerprint =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  const checks = [
    'local_backend_1v1_test',
    'revenuecat_roundtrip_test',
    'notification_real_schedule_test',
    'os_level_resilience_test',
  ];

  Map<String, dynamic> validEvidence() => {
    'version': version,
    'source_fingerprint': sourceFingerprint,
    'verified_at': '2026-09-13T12:00:00Z',
    'checks': {
      for (final check in checks)
        check: {'passed': true, 'device': 'release-device'},
    },
  };

  test('tam cihaz kanıtı kabul edilir', () {
    expect(
      validateDeviceReleaseEvidence(
        jsonEncode(validEvidence()),
        expectedVersion: version,
        expectedSourceFingerprint: sourceFingerprint,
      ),
      isEmpty,
    );
  });

  test('sürüm uyuşmazlığı ve eksik cihaz testi reddedilir', () {
    final evidence = validEvidence();
    evidence['version'] = '1.9.2+19';
    final map = evidence['checks']! as Map<String, dynamic>;
    map['revenuecat_roundtrip_test'] = {'passed': false, 'device': ''};

    final errors = validateDeviceReleaseEvidence(
      jsonEncode(evidence),
      expectedVersion: version,
      expectedSourceFingerprint: sourceFingerprint,
    );

    expect(errors, isNotEmpty);
    expect(errors.join('\n'), contains('1.9.2+20'));
    expect(errors.join('\n'), contains('revenuecat_roundtrip_test'));
  });

  test('aynı sürümde farklı aday kaynak eski cihaz kanıtını reddeder', () {
    final errors = validateDeviceReleaseEvidence(
      jsonEncode(validEvidence()),
      expectedVersion: version,
      expectedSourceFingerprint:
          'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
    );

    expect(errors.join('\n'), contains('kaynak parmak izi'));
  });
}
