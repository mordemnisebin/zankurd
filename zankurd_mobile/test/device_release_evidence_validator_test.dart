import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
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

  group('dosya doğrulaması (filesBase verilince)', () {
    late Directory dir;
    setUp(() {
      dir = Directory.systemTemp.createTempSync('cihaz_kanit_');
      addTearDown(() => dir.deleteSync(recursive: true));
    });

    String write(String name, String content) {
      File('${dir.path}/$name')
        ..createSync(recursive: true)
        ..writeAsStringSync(content);
      return sha256.convert(utf8.encode(content)).toString();
    }

    Map<String, dynamic> gercek() {
      final e = validEvidence();
      e['artifacts'] = {
        'android': {'ref': 'app.aab', 'sha256': write('app.aab', 'aab-bytes')},
        'ios': {'ref': 'app.ipa', 'sha256': write('app.ipa', 'ipa-bytes')},
      };
      e['checks'] = {
        for (final c in checks)
          c: {
            'passed': true,
            'device': 'release-device',
            'evidence_ref': 'evidence/$c.log',
            'evidence_sha256': write('evidence/$c.log', 'ok $c'),
          },
      };
      return e;
    }

    List<String> run(Map<String, dynamic> e) => validateDeviceReleaseEvidence(
      jsonEncode(e),
      expectedVersion: version,
      expectedSourceFingerprint: sourceFingerprint,
      now: DateTime.utc(2026, 9, 25, 10),
      filesBase: dir,
    );

    test('gerçek dosyalar ve doğru hash kabul edilir', () {
      expect(run(gercek()), isEmpty);
    });

    test('olmayan dosya referansı reddedilir', () {
      final e = gercek();
      ((e['checks'] as Map)['os_level_resilience_test']
              as Map)['evidence_ref'] =
          'yok.log';
      expect(run(e), contains(contains('bulunamadı')));
    });

    test('yanlış hash ve 64 sıfır reddedilir', () {
      final e = gercek();
      (e['artifacts'] as Map)['android'] = {
        'ref': 'app.aab',
        'sha256': 'b' * 64,
      };
      (e['artifacts'] as Map)['ios'] = {'ref': 'app.ipa', 'sha256': '0' * 64};
      final errors = run(e);
      expect(errors, contains(contains('uyuşmuyor')));
      expect(errors, contains(contains('sıfır')));
    });

    test('dizin artifact olarak kabul edilmez', () {
      Directory('${dir.path}/Runner.app').createSync();
      final e = gercek();
      (e['artifacts'] as Map)['ios'] = {
        'ref': 'Runner.app',
        'sha256': 'c' * 64,
      };
      expect(run(e), contains(contains('bulunamadı')));
    });
  });
}
