import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/services/native_auth_service.dart';

void main() {
  test('Google credential keeps the ID token and access token', () {
    const credential = NativeAuthCredential.google(
      idToken: 'google-id-token',
      accessToken: 'google-access-token',
    );

    expect(credential.provider, NativeAuthProvider.google);
    expect(credential.idToken, 'google-id-token');
    expect(credential.accessToken, 'google-access-token');
    expect(credential.nonce, isNull);
  });

  test('Apple credential keeps the raw nonce for Supabase verification', () {
    const credential = NativeAuthCredential.apple(
      idToken: 'apple-id-token',
      rawNonce: 'raw-nonce',
    );

    expect(credential.provider, NativeAuthProvider.apple);
    expect(credential.idToken, 'apple-id-token');
    expect(credential.nonce, 'raw-nonce');
    expect(credential.accessToken, isNull);
  });

  test('a cancelled native sign-in is represented without an auth error', () {
    expect(const NativeAuthCancelled(), isA<NativeAuthCancelled>());
    expect(const NativeAuthCancelled().toString(), 'NativeAuthCancelled');
  });
}
