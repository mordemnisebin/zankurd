import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/providers/auth_provider.dart';

void main() {
  test(
    'offline auth hesap girişini reddeder, yerel misafire izin verir',
    () async {
      final provider = AuthProvider.offline();
      addTearDown(provider.dispose);

      final signedIn = await provider.signInWithEmail(
        email: 'rojda@example.com',
        password: 'secret123',
      );

      expect(signedIn, isFalse);
      expect(provider.isAuthenticated, isFalse);
      expect(
        provider.errorMessage,
        'Bağlantı kurulamadı. İnternet/DNS erişimini kontrol et.',
      );

      expect(await provider.signInAsGuest(), isTrue);
      expect(provider.isAuthenticated, isTrue);
    },
  );
}
