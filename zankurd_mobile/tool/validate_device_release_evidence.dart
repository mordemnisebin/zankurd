import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

const requiredDeviceReleaseChecks = <String>[
  'local_backend_1v1_test',
  'revenuecat_roundtrip_test',
  'notification_real_schedule_test',
  'os_level_resilience_test',
];

List<String> validateDeviceReleaseEvidence(
  String source, {
  required String expectedVersion,
  required String expectedSourceFingerprint,
}) {
  final errors = <String>[];
  Object? decoded;
  try {
    decoded = jsonDecode(source);
  } on FormatException {
    return ['Cihaz kanıtı geçerli JSON değil.'];
  }
  if (decoded is! Map<String, dynamic>) {
    return ['Cihaz kanıtının kökü JSON nesnesi olmalı.'];
  }

  final version = decoded['version'];
  if (version != expectedVersion) {
    errors.add(
      'Kanıt sürümü $expectedVersion olmalı; bulunan: ${version ?? 'yok'}.',
    );
  }
  final sourceFingerprint = decoded['source_fingerprint'];
  if (sourceFingerprint is! String ||
      !RegExp(r'^[a-f0-9]{64}$').hasMatch(sourceFingerprint)) {
    errors.add('source_fingerprint 64 karakterlik SHA-256 olmalı.');
  } else if (sourceFingerprint != expectedSourceFingerprint) {
    errors.add(
      'Cihaz kanıtının kaynak parmak izi mevcut aday kaynakla eşleşmiyor. '
      'Cihaz testlerini bu aday kaynak üzerinde yeniden çalıştır.',
    );
  }
  final verifiedAt = decoded['verified_at'];
  if (verifiedAt is! String || DateTime.tryParse(verifiedAt) == null) {
    errors.add('verified_at geçerli ISO-8601 tarih/saat olmalı.');
  }

  final checks = decoded['checks'];
  if (checks is! Map<String, dynamic>) {
    errors.add('checks nesnesi eksik.');
    return errors;
  }
  for (final name in requiredDeviceReleaseChecks) {
    final value = checks[name];
    if (value is! Map<String, dynamic>) {
      errors.add('$name kanıtı eksik.');
      continue;
    }
    if (value['passed'] != true) {
      errors.add('$name passed=true olmalı.');
    }
    final device = value['device'];
    if (device is! String || device.trim().isEmpty) {
      errors.add('$name için cihaz bilgisi boş olamaz.');
    }
  }
  return errors;
}

String computeReleaseSourceFingerprint({Directory? workingDirectory}) {
  final root = workingDirectory ?? Directory.current;
  final result = Process.runSync('git', [
    'ls-files',
    '-c',
    '-o',
    '--exclude-standard',
    '-z',
    '--',
    'lib',
    'assets',
    'android',
    'ios',
    'pubspec.yaml',
    'pubspec.lock',
  ], workingDirectory: root.path);
  if (result.exitCode != 0) {
    throw StateError('Release kaynak listesi Git üzerinden okunamadı.');
  }

  final paths = (result.stdout as String)
      .split('\x00')
      .where((path) => path.isNotEmpty)
      .toSet();
  if (File('${root.path}/.env.mobile.release.json').existsSync()) {
    paths.add('.env.mobile.release.json');
  }

  final orderedPaths = paths.toList()..sort();
  final bytes = BytesBuilder(copy: false);
  for (final path in orderedPaths) {
    bytes.add(utf8.encode(path));
    bytes.addByte(0);
    final file = File('${root.path}/$path');
    if (file.existsSync()) {
      bytes.add(file.readAsBytesSync());
    } else {
      bytes.add(utf8.encode('<missing>'));
    }
    bytes.addByte(0);
  }
  return sha256.convert(bytes.takeBytes()).toString();
}

String _readPackageVersion(File pubspec) {
  final match = RegExp(
    r'^version:\s*([^\s#]+)',
    multiLine: true,
  ).firstMatch(pubspec.readAsStringSync());
  if (match == null) {
    throw StateError('pubspec.yaml içinde version bulunamadı.');
  }
  return match.group(1)!;
}

void main(List<String> args) {
  var path = '.release-device-evidence.json';
  var printSourceFingerprint = false;
  for (var index = 0; index < args.length; index++) {
    final arg = args[index];
    if (arg.startsWith('--file=')) {
      path = arg.substring('--file='.length);
    } else if (arg == '--file' && index + 1 < args.length) {
      path = args[++index];
    } else if (arg == '--print-source-fingerprint') {
      printSourceFingerprint = true;
    } else {
      stderr.writeln('Bilinmeyen argüman: $arg');
      exitCode = 64;
      return;
    }
  }

  String sourceFingerprint;
  try {
    sourceFingerprint = computeReleaseSourceFingerprint();
  } catch (error) {
    stderr.writeln(error);
    exitCode = 2;
    return;
  }
  if (printSourceFingerprint) {
    stdout.writeln(sourceFingerprint);
    return;
  }

  final evidence = File(path);
  if (!evidence.existsSync()) {
    stderr.writeln('Cihaz kanıtı bulunamadı: $path');
    exitCode = 2;
    return;
  }

  final expectedVersion = _readPackageVersion(File('pubspec.yaml'));
  final errors = validateDeviceReleaseEvidence(
    evidence.readAsStringSync(),
    expectedVersion: expectedVersion,
    expectedSourceFingerprint: sourceFingerprint,
  );
  if (errors.isNotEmpty) {
    for (final error in errors) {
      stderr.writeln('- $error');
    }
    exitCode = 1;
    return;
  }

  stdout.writeln(
    'Device release evidence passed for $expectedVersion '
    '(${requiredDeviceReleaseChecks.length}/${requiredDeviceReleaseChecks.length}).',
  );
}
