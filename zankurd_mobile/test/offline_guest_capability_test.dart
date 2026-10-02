import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/providers/auth_provider.dart';

void main() {
  test(
    'offline misafir gerçek misafir olarak işaretlenir ve remote yazamaz',
    () async {
      final provider = AuthProvider.offline();
      addTearDown(provider.dispose);

      expect(provider.isGuest, isFalse);
      expect(provider.canUseRemoteActions, isFalse);
      expect(await provider.signInAsGuest(), isTrue);
      expect(provider.isAuthenticated, isTrue);
      expect(provider.isGuest, isTrue);
      expect(provider.canUseRemoteActions, isFalse);
    },
  );
}
