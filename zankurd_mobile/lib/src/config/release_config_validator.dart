import 'dart:convert';

enum RevenueCatPlatform { android, ios }

/// Release derlemelerine gömülecek açık istemci değerlerinin yan etkisiz
/// doğrulayıcısı.
class ReleaseConfigValidator {
  const ReleaseConfigValidator._();

  static final _supabaseProjectHost = RegExp(
    r'^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.supabase\.co$',
  );
  static final _supabasePublishableKey = RegExp(
    r'^sb_publishable_[A-Za-z0-9_-]{20,}$',
  );
  static final _revenueCatPublicKeyBody = RegExp(r'^[A-Za-z0-9_-]{20,}$');

  static const _templateMarkers = <String>[
    'your-project',
    'your-public-',
    'your_public_',
    'replace-me',
    'replace_me',
    'changeme',
    'placeholder',
  ];

  static bool isSafeSupabaseUrl(String value) {
    if (!_isExactValue(value)) return false;
    final uri = Uri.tryParse(value);
    if (uri == null ||
        uri.scheme != 'https' ||
        !uri.hasAuthority ||
        uri.userInfo.isNotEmpty ||
        uri.host.isEmpty ||
        !_supabaseProjectHost.hasMatch(uri.host.toLowerCase()) ||
        (uri.hasPort && uri.port != 443) ||
        (uri.path.isNotEmpty && uri.path != '/') ||
        uri.hasQuery ||
        uri.hasFragment) {
      return false;
    }
    return true;
  }

  static bool isSafeSupabaseClientKey(String value) {
    if (!_isExactValue(value)) return false;
    if (_supabasePublishableKey.hasMatch(value)) return true;
    if (value.startsWith('sb_')) return false;

    final parts = value.split('.');
    if (parts.length != 3 || parts.any((part) => part.isEmpty)) return false;
    try {
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      return payload is Map<String, dynamic> && payload['role'] == 'anon';
    } on FormatException {
      return false;
    }
  }

  static bool isSafeRevenueCatKey(
    String value, {
    required RevenueCatPlatform platform,
    bool allowTestStoreKey = false,
  }) {
    if (!_isExactValue(value)) return false;

    final separator = value.indexOf('_');
    if (separator <= 0 || separator == value.length - 1) return false;
    final prefix = value.substring(0, separator + 1);
    final body = value.substring(separator + 1);
    if (!_revenueCatPublicKeyBody.hasMatch(body)) return false;

    if (allowTestStoreKey && prefix == 'test_') return true;
    return switch (platform) {
      RevenueCatPlatform.android => prefix == 'goog_',
      RevenueCatPlatform.ios => prefix == 'appl_',
    };
  }

  static bool _isExactValue(String value) {
    if (value.isEmpty || value != value.trim()) return false;
    final normalized = value.toLowerCase();
    return !_templateMarkers.any(normalized.contains);
  }
}
