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
    'verified_at': '2026-09-25T06:00:00Z',
    'artifacts': {
      'android': {'ref': 'build/app-release.aab', 'sha256': sourceFingerprint},
      'ios': {'ref': 'build/Runner.app', 'sha256': sourceFingerprint},
    },
    'checks': {
      for (final check in checks)
        check: {
          'passed': true,
          'device': 'release-device',
          'evidence_ref': 'evidence/$check.log',
          'evidence_sha256': sourceFingerprint,
        },
    },
  };

  test('tam cihaz kanıtı kabul edilir', () {
    expect(
      validateDeviceReleaseEvidence(
        jsonEncode(validEvidence()),
        expectedVersion: version,
        expectedSourceFingerprint: sourceFingerprint,
        now: DateTime.utc(2026, 9, 25, 10),
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
      now: DateTime.utc(2026, 9, 25, 10),
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
      now: DateTime.utc(2026, 9, 25, 10),
    );

    expect(errors.join('\n'), contains('kaynak parmak izi'));
  });

  test('eski veya gelecekteki cihaz kanıtı reddedilir', () {
    final old = validEvidence()..['verified_at'] = '2026-09-10T12:00:00Z';
    final oldErrors = validateDeviceReleaseEvidence(
      jsonEncode(old),
      expectedVersion: version,
      expectedSourceFingerprint: sourceFingerprint,
      now: DateTime.utc(2026, 9, 25, 10),
    );
    expect(oldErrors.join('\n'), contains('günden eski'));

    final future = validEvidence()..['verified_at'] = '2026-09-26T12:00:00Z';
    final futureErrors = validateDeviceReleaseEvidence(
      jsonEncode(future),
      expectedVersion: version,
      expectedSourceFingerprint: sourceFingerprint,
      now: DateTime.utc(2026, 9, 25, 10),
    );
    expect(futureErrors.join('\n'), contains('gelecekte'));
  });

  test('log hash veya release artifact kanıtı eksikse reddedilir', () {
    final evidence = validEvidence();
    (evidence['checks'] as Map<String, dynamic>)['local_backend_1v1_test'] = {
      'passed': true,
      'device': 'release-device',
    };
    evidence.remove('artifacts');

    final errors = validateDeviceReleaseEvidence(
      jsonEncode(evidence),
      expectedVersion: version,
      expectedSourceFingerprint: sourceFingerprint,
      now: DateTime.utc(2026, 9, 25, 10),
    );
    expect(errors.join('\n'), contains('artifacts'));
    expect(errors.join('\n'), contains('evidence_sha256'));
  });
}
