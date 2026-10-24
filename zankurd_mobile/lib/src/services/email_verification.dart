import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/error_reporter.dart';

/// Nazik e-posta doğrulamasının arka ucu (6 haneli kod).
///
/// ## Niçin ayrı bir kapı
///
/// E-posta/parola hesapları "Confirm email KAPALI" olduğundan kayıtta
/// otomatik onaylanır; `email_confirmed_at` bir doğrulama kanıtı DEĞİLDİR.
/// Kanıt, kullanıcının e-postasına giden kodu girmesidir: `signInWithOtp`
/// kodu yollar, `verifyOTP` oturumu OTP yöntemiyle yeniler, sunucudaki
/// `mark_my_email_verified()` JWT'nin `amr` talebinde taze bir `otp`
/// yöntemi görürse `profiles.email_verified_at`ı yazar. Oyun ve sıralama bu
/// bayrakla KAPILANMAZ.
///
/// Arayüz bu soyut sınıfla konuşur; testlerde sahte uygulanır.
abstract class EmailVerificationGateway {
  /// Doğrulanacak adres; e-posta hesabı değilse null.
  String? get email;

  /// Kod ile doğrulanabilecek bir e-posta/parola hesabı mı. Google/Apple
  /// hesapları sağlayıcı tarafından doğrulanmış sayılır (false); misafir
  /// (anonim) hesabın adresi yoktur (false).
  bool get needsVerification;

  /// Sunucudaki doğrulama durumu; bilinmiyorsa (çevrimdışı) null.
  Future<bool?> isVerified();

  /// Adrese 6 haneli kodu yollar.
  Future<void> sendCode();

  /// Kodu doğrular. Hata `EmailVerificationException` fırlatır.
  Future<void> verifyCode(String code);

  /// Sunucuya "doğrulandı" işaretini yazdırır; başarıyı döner.
  Future<bool> markVerified();
}

enum EmailVerificationFailure {
  /// Kod yanlış ya da süresi dolmuş.
  badCode,

  /// Kod doğrulandı ama oturum başka bir kullanıcıya döndü (olmamalı).
  differentUser,

  /// Ağ/sunucu.
  network,
}

class EmailVerificationException implements Exception {
  const EmailVerificationException(this.failure);

  final EmailVerificationFailure failure;

  @override
  String toString() => 'EmailVerificationException($failure)';
}

class SupabaseEmailVerificationGateway implements EmailVerificationGateway {
  SupabaseEmailVerificationGateway(this._client);

  final SupabaseClient _client;

  User? get _user => _client.auth.currentUser;

  @override
  String? get email {
    final value = _user?.email?.trim();
    return (value == null || value.isEmpty) ? null : value;
  }

  @override
  bool get needsVerification {
    final user = _user;
    if (user == null || user.isAnonymous || email == null) return false;
    final provider = user.appMetadata['provider'];
    final providers = user.appMetadata['providers'];
    // Sağlayıcı kimliği (Google/Apple) adresi zaten doğrulamıştır.
    if (providers is List &&
        providers.any((p) => p == 'google' || p == 'apple')) {
      return false;
    }
    return provider == null || provider == 'email';
  }

  @override
  Future<bool?> isVerified() async {
    try {
      final response = await _client.rpc('get_my_account_flags');
      if (response is Map<String, dynamic> && response['success'] == true) {
        return response['email_verified_at'] != null;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> sendCode() async {
    final address = email;
    if (address == null) {
      throw const EmailVerificationException(EmailVerificationFailure.network);
    }
    try {
      // shouldCreateUser: false — yeni hesap AÇMAZ, yalnız bu adrese kod yollar.
      await _client.auth.signInWithOtp(email: address, shouldCreateUser: false);
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'email_verify_send');
      throw const EmailVerificationException(EmailVerificationFailure.network);
    }
  }

  @override
  Future<void> verifyCode(String code) async {
    final address = email;
    final previousId = _user?.id;
    if (address == null) {
      throw const EmailVerificationException(EmailVerificationFailure.badCode);
    }
    try {
      final response = await _client.auth.verifyOTP(
        email: address,
        token: code,
        type: OtpType.email,
      );
      final next = response.user?.id ?? _user?.id;
      if (previousId != null && next != previousId) {
        throw const EmailVerificationException(
          EmailVerificationFailure.differentUser,
        );
      }
    } on EmailVerificationException {
      rethrow;
    } on AuthException {
      throw const EmailVerificationException(EmailVerificationFailure.badCode);
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'email_verify_check');
      throw const EmailVerificationException(EmailVerificationFailure.network);
    }
  }

  @override
  Future<bool> markVerified() async {
    try {
      final response = await _client.rpc('mark_my_email_verified');
      return response is Map<String, dynamic> && response['success'] == true;
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'email_verify_mark');
      return false;
    }
  }
}
