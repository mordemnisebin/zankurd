/// Kimlik ve abonelik hata iletileri metin anahtarıdır, sabit Türkçe değil.
///
/// Kusur: `AuthProvider._translateError` ve `PremiumService` kullanıcıya
/// giden iletileri doğrudan Türkçe dize olarak üretiyordu; Kurmancî kullanıcı
/// ya Türkçe hata görüyordu ya da `lang.dart`taki elle tutulan Türkçe→Kurmancî
/// eşlemesi bir cümleyi kaçırınca genel cümleye düşüyordu.
///
/// Niçin sessizdi: Türkçe arayüz hep doğru görünüyordu; eşleme yalnız
/// Kurmancîde, yalnız o hata olunca devreye giriyordu ve test Türkçe ham
/// metni bekliyordu.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/l10n/strings.dart';
import 'package:zankurd_mobile/src/providers/auth_provider.dart';

void main() {
  test('her çevrilmiş kimlik hatası kayıtlı bir anahtardır (KU+TR dolu)', () {
    final provider = AuthProvider.test();
    final cases = <AuthException>[
      const AuthException('net::ERR_NAME_NOT_RESOLVED'),
      const AuthException('x', code: 'identity_already_exists'),
      const AuthException('x', code: 'manual_linking_disabled'),
      const AuthException('Unsupported provider'),
      const AuthException('validation_failed'),
      const AuthException('Invalid login credentials'),
      const AuthException('User already registered'),
      const AuthException('Password should be at least 6 characters'),
      const AuthException('Invalid email'),
      const AuthException('Email not confirmed'),
      const AuthException('email rate limit exceeded'),
      const AuthException('Anonymous sign-ins are disabled'),
      const AuthException('bilinmeyen'),
    ];
    for (final e in cases) {
      final key = provider.debugTranslateAuthError(e);
      expect(Tr.hasKey(key), isTrue, reason: '${e.message} -> $key');
      expect(Tr.of(key, AppLanguage.ku).trim(), isNotEmpty);
      expect(Tr.of(key, AppLanguage.tr).trim(), isNotEmpty);
    }
    expect(
      Tr.hasKey(provider.debugTranslateUnexpectedAuthError(Exception('x'))),
      isTrue,
    );
  });

  test('Kurmancî metinler Türkçe değil (Hawar alfabesi, ı ğ ö ü yok)', () {
    for (final key in Tr.keys.where(
      (k) => k.startsWith('auth.err.') || k.startsWith('premium.'),
    )) {
      final ku = Tr.of(key, AppLanguage.ku);
      expect(ku, isNot(matches(RegExp(r'[ığöüİĞÖÜ]'))), reason: key);
    }
  });

  test('sağlayıcı ve abonelik servisi sabit Türkçe ileti atamaz', () {
    final auth = File(
      'lib/src/providers/auth_provider.dart',
    ).readAsStringSync();
    final premium = File(
      'lib/src/services/premium_service.dart',
    ).readAsStringSync();
    final literal = RegExp(r"_(error|info)Message\s*=\s*'");
    expect(literal.hasMatch(auth), isFalse);
    expect(literal.hasMatch(premium), isFalse);
    expect(auth, isNot(contains("return 'Bağlantı kurulamadı")));
    expect(premium, isNot(contains("'Satın alma sırasında")));
  });
}
