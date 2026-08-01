import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('yeni profil yolu geçerli avatar rengi gönderir', () {
    final source = File(
      'lib/src/data/supabase_zankurd_repository.dart',
    ).readAsStringSync();

    expect(source, contains("_defaultAvatarColor = '#2E9E93'"));
    expect(source, contains('avatarColor: _defaultAvatarColor'));
  });

  test('mevcut profilin avatar rengi ad değişiminde korunur', () {
    final source = File(
      'lib/src/data/supabase_zankurd_repository.dart',
    ).readAsStringSync();
    final method = source.substring(
      source.indexOf('Future<void> updateProfileName'),
      source.indexOf('Future<AvatarIdentity> loadAvatarIdentity'),
    );

    expect(method, contains('maybeSingle()'));
    expect(method, contains('avatarColor: existing == null'));
  });
}
