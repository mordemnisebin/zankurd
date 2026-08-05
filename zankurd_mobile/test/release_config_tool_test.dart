import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync(
      'zankurd-release-config-test-',
    );
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  test('production mobile config validates both platform SDK keys', () async {
    final config = _writeConfig(tempDir, {
      ..._safeSupabaseConfig,
      'REVENUECAT_API_KEY_ANDROID': 'goog_abcdefghijklmnopqrstuvwxyz012345',
      'REVENUECAT_API_KEY_IOS': 'appl_abcdefghijklmnopqrstuvwxyz012345',
    });

    final result = await _runValidator(
      config,
      target: 'mobile',
      environment: 'production',
    );

    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
  });

  test('unsafe values fail without being echoed', () async {
    const secretValue =
        'sb_'
        'secret_do_not_echo_abcdefghijklmnopqrstuvwxyz';
    const wrongPlatformKey = 'appl_do_not_echo_abcdefghijklmnopqrstuvwxyz';
    final config = _writeConfig(tempDir, {
      'SUPABASE_URL': 'https://abcdefghijklmnopqrst.supabase.co',
      'SUPABASE_ANON_KEY': secretValue,
      'REVENUECAT_API_KEY_ANDROID': wrongPlatformKey,
      'REVENUECAT_API_KEY_IOS': 'appl_abcdefghijklmnopqrstuvwxyz012345',
    });

    final result = await _runValidator(
      config,
      target: 'mobile',
      environment: 'production',
    );
    final output = '${result.stdout}\n${result.stderr}';

    expect(result.exitCode, isNot(0));
    expect(output, contains('SUPABASE'));
    expect(output, contains('REVENUECAT_API_KEY_ANDROID'));
    expect(output, isNot(contains(secretValue)));
    expect(output, isNot(contains(wrongPlatformKey)));
  });

  test('unexpected fields fail without echoing their values', () async {
    const unexpectedSecret = 'must-not-appear-in-validator-output';
    final config = _writeConfig(tempDir, {
      ..._safeSupabaseConfig,
      'REVENUECAT_API_KEY_ANDROID': 'goog_abcdefghijklmnopqrstuvwxyz012345',
      'REVENUECAT_API_KEY_IOS': 'appl_abcdefghijklmnopqrstuvwxyz012345',
      'SUPABASE_SERVICE_ROLE_KEY': unexpectedSecret,
    });

    final result = await _runValidator(
      config,
      target: 'mobile',
      environment: 'production',
    );
    final output = '${result.stdout}\n${result.stderr}';

    expect(result.exitCode, isNot(0));
    expect(output, contains('beklenmeyen'));
    expect(output, isNot(contains(unexpectedSecret)));
  });

  test('Test Store key requires an explicit staging environment', () async {
    final config = _writeConfig(tempDir, {
      ..._safeSupabaseConfig,
      'REVENUECAT_API_KEY_ANDROID': 'test_abcdefghijklmnopqrstuvwxyz012345',
      'REVENUECAT_API_KEY_IOS': 'test_abcdefghijklmnopqrstuvwxyz012345',
    });

    final production = await _runValidator(
      config,
      target: 'mobile',
      environment: 'production',
    );
    final staging = await _runValidator(
      config,
      target: 'mobile',
      environment: 'staging',
    );

    expect(production.exitCode, isNot(0));
    expect(staging.exitCode, 0, reason: '${staging.stdout}\n${staging.stderr}');
  });
}

const _safeSupabaseConfig = <String, String>{
  'SUPABASE_URL': 'https://abcdefghijklmnopqrst.supabase.co',
  'SUPABASE_ANON_KEY': 'sb_publishable_abcdefghijklmnopqrstuvwxyz0123456789',
};

File _writeConfig(Directory directory, Map<String, String> values) {
  final file = File('${directory.path}/config.json');
  file.writeAsStringSync(jsonEncode(values));
  return file;
}

Future<ProcessResult> _runValidator(
  File config, {
  required String target,
  required String environment,
}) => Process.run('dart', [
  'run',
  'tool/validate_release_config.dart',
  '--file=${config.path}',
  '--target=$target',
  '--environment=$environment',
]);
