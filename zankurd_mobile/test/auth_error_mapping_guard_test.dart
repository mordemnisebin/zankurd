// Bekçi: Supabase auth hata eşlemesi (A1, A2).
//
// ## Kusur
// `_translateError` mesajda `'uri'` alt dizgisi arıyordu. Supabase'in hız
// sınırı mesajı "For security purposes, you can only request this after 30
// seconds." içinde "sec-URI-ty" geçer; kullanıcı "yönlendirme ayarlarını
// kontrol et" (geliştirici dili) görüyordu. Ayrıca "New password should be
// different from the old password." mesajı `password should be` ile eşleşip
// "Parola çok zayıf" diye gösteriliyordu.
//
// ## Niçin sessiz kalırdı
// Her iki durumda da bir hata metni görünüyordu; yalnız YANLIŞ metindi, bu
// yüzden ne çökme ne log vardı. Testler yalnız tek tek bilinen mesajları
// denerdi.
//
// ## Kural
// Önce `AuthException.code` (kararlı), sonra dar alt dizgi. Hız sınırı
// yönlendirme kontrolünden ÖNCE bakılır. Aynı parola ayrı mesaj alır.
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zankurd_mobile/src/providers/auth_provider.dart';

void main() {
  const rateLimit = 'Çok fazla deneme yapıldı. Biraz bekleyip tekrar dene.';
  const redirect =
      'Giriş bağlantısı doğrulanamadı. Uygulama yönlendirme ayarlarını kontrol et.';

  String tr(AuthException e) => AuthProvider.test().debugTranslateAuthError(e);

  test('"For security purposes" hız sınırı yönlendirme hatası sanılmaz', () {
    final msg = tr(
      const AuthException(
        'For security purposes, you can only request this after 30 seconds.',
        statusCode: '429',
      ),
    );
    expect(msg, rateLimit);
    expect(msg, isNot(redirect));
  });

  test('over_email_send_rate_limit kodu hız sınırına eşlenir', () {
    expect(
      tr(
        const AuthException(
          'Email rate limit exceeded',
          statusCode: '429',
          code: 'over_email_send_rate_limit',
        ),
      ),
      rateLimit,
    );
    expect(
      tr(
        const AuthException(
          'Request rate limit reached',
          statusCode: '429',
          code: 'over_request_rate_limit',
        ),
      ),
      rateLimit,
    );
  });

  test('gerçek redirect hatası yine yönlendirme mesajı verir', () {
    expect(
      tr(const AuthException('redirect_to is not allowed', statusCode: '400')),
      redirect,
    );
  });

  test('aynı parola ayrı mesaj alır, "zayıf" denmez', () {
    final msg = tr(
      const AuthException(
        'New password should be different from the old password.',
        statusCode: '422',
        code: 'same_password',
      ),
    );
    expect(msg, isNot(contains('zayıf')));
    expect(msg, 'Yeni parola eskisinden farklı olmalı.');
  });

  test('aynı parola mesajı koddan bağımsız metinle de yakalanır', () {
    final msg = tr(
      const AuthException(
        'New password should be different from the old password.',
      ),
    );
    expect(msg, 'Yeni parola eskisinden farklı olmalı.');
  });

  test('weak_password kodu zayıf parola mesajı verir', () {
    expect(
      tr(
        const AuthException(
          'Password is known to be weak',
          statusCode: '422',
          code: 'weak_password',
        ),
      ),
      'Parola çok zayıf (en az 6 karakter).',
    );
  });
}
