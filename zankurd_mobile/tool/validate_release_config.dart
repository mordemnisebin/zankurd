import 'dart:convert';
import 'dart:io';

import 'package:zankurd_mobile/src/config/release_config_validator.dart';

void main(List<String> args) {
  final options = _Options.tryParse(args);
  if (options == null) {
    stderr.writeln(
      'Kullanım: dart run tool/validate_release_config.dart '
      '--file=<json> --target=<mobile|web> '
      '--environment=<production|staging>',
    );
    exitCode = 64;
    return;
  }

  final Map<String, dynamic> values;
  try {
    final decoded = jsonDecode(File(options.filePath).readAsStringSync());
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException();
    }
    values = decoded;
  } on FileSystemException {
    stderr.writeln('Yapılandırma dosyası okunamadı; değerler yazdırılmadı.');
    exitCode = 66;
    return;
  } on FormatException {
    stderr.writeln('Yapılandırma JSON biçimi geçersiz; değerler yazdırılmadı.');
    exitCode = 65;
    return;
  }

  final allowedFields = switch (options.target) {
    _Target.web => const {'SUPABASE_URL', 'SUPABASE_ANON_KEY'},
    _Target.mobile => const {
      'SUPABASE_URL',
      'SUPABASE_ANON_KEY',
      'REVENUECAT_API_KEY_ANDROID',
      'REVENUECAT_API_KEY_IOS',
    },
  };
  if (values.keys.any((field) => !allowedFields.contains(field))) {
    stderr.writeln(
      'Yapılandırmada beklenmeyen alan var; değerler yazdırılmadı.',
    );
    exitCode = 65;
    return;
  }

  final invalidFields = <String>[];
  final supabaseUrl = _stringValue(values, 'SUPABASE_URL');
  final supabaseKey = _stringValue(values, 'SUPABASE_ANON_KEY');
  if (!ReleaseConfigValidator.isSafeSupabaseUrl(supabaseUrl)) {
    invalidFields.add('SUPABASE_URL');
  }
  if (!ReleaseConfigValidator.isSafeSupabaseClientKey(supabaseKey)) {
    invalidFields.add('SUPABASE_ANON_KEY');
  }

  if (options.target == _Target.mobile) {
    final allowTestStoreKey = options.environment == _Environment.staging;
    final androidKey = _stringValue(values, 'REVENUECAT_API_KEY_ANDROID');
    final iosKey = _stringValue(values, 'REVENUECAT_API_KEY_IOS');
    if (!ReleaseConfigValidator.isSafeRevenueCatKey(
      androidKey,
      platform: RevenueCatPlatform.android,
      allowTestStoreKey: allowTestStoreKey,
    )) {
      invalidFields.add('REVENUECAT_API_KEY_ANDROID');
    }
    if (!ReleaseConfigValidator.isSafeRevenueCatKey(
      iosKey,
      platform: RevenueCatPlatform.ios,
      allowTestStoreKey: allowTestStoreKey,
    )) {
      invalidFields.add('REVENUECAT_API_KEY_IOS');
    }
  }

  if (invalidFields.isNotEmpty) {
    stderr.writeln(
      'Yapılandırma geçersiz: ${invalidFields.join(', ')}. '
      'Değerler güvenlik için yazdırılmadı.',
    );
    exitCode = 65;
    return;
  }

  stdout.writeln(
    '${options.target.label} ${options.environment.label} '
    'istemci yapılandırması geçerli; değerler yazdırılmadı.',
  );
}

String _stringValue(Map<String, dynamic> values, String key) {
  final value = values[key];
  return value is String ? value : '';
}

enum _Target {
  mobile,
  web;

  String get label => name;
}

enum _Environment {
  production,
  staging;

  String get label => name;
}

class _Options {
  const _Options({
    required this.filePath,
    required this.target,
    required this.environment,
  });

  final String filePath;
  final _Target target;
  final _Environment environment;

  static _Options? tryParse(List<String> args) {
    if (args.length != 3) return null;
    final values = <String, String>{};
    for (final argument in args) {
      final separator = argument.indexOf('=');
      if (!argument.startsWith('--') || separator <= 2) return null;
      final key = argument.substring(2, separator);
      final value = argument.substring(separator + 1);
      if (value.isEmpty || values.containsKey(key)) return null;
      values[key] = value;
    }

    final target = _Target.values.where((item) {
      return item.name == values['target'];
    }).firstOrNull;
    final environment = _Environment.values.where((item) {
      return item.name == values['environment'];
    }).firstOrNull;
    final filePath = values['file'];
    if (filePath == null || target == null || environment == null) return null;
    return _Options(
      filePath: filePath,
      target: target,
      environment: environment,
    );
  }
}
