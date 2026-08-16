import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';

enum NativeAuthProvider { google, apple }

/// SDK'lerden gelen ve Supabase'in ID-token akışına aktarılacak ortak veri.
class NativeAuthCredential {
  const NativeAuthCredential({
    required this.provider,
    required this.idToken,
    this.accessToken,
    this.nonce,
  });

  const NativeAuthCredential.google({
    required String idToken,
    String? accessToken,
  }) : this(
         provider: NativeAuthProvider.google,
         idToken: idToken,
         accessToken: accessToken,
       );

  const NativeAuthCredential.apple({
    required String idToken,
    required String rawNonce,
  }) : this(
         provider: NativeAuthProvider.apple,
         idToken: idToken,
         nonce: rawNonce,
       );

  final NativeAuthProvider provider;
  final String idToken;
  final String? accessToken;
  final String? nonce;
}

/// Kullanıcının sağlayıcı ekranını kapatması hata değildir.
class NativeAuthCancelled implements Exception {
  const NativeAuthCancelled();

  @override
  String toString() => 'NativeAuthCancelled';
}

abstract interface class NativeAuthService {
  Future<NativeAuthCredential?> signInWithGoogle();

  Future<NativeAuthCredential?> signInWithApple();
}

/// iOS/Android native sağlayıcı SDK'larının tek giriş noktası.
class PlatformNativeAuthService implements NativeAuthService {
  PlatformNativeAuthService({this.supabaseClient});

  final SupabaseClient? supabaseClient;
  GoogleSignIn? _googleSignIn;
  Future<void>? _googleInitialization;

  GoogleSignIn get _configuredGoogleSignIn {
    final existing = _googleSignIn;
    if (existing != null) return existing;

    final signIn = GoogleSignIn.instance;
    _googleSignIn = signIn;
    _googleInitialization = signIn.initialize(
      clientId: AppConfig.googleIosClientId.isEmpty
          ? null
          : AppConfig.googleIosClientId,
      serverClientId: AppConfig.googleWebClientId,
    );
    return signIn;
  }

  @override
  Future<NativeAuthCredential?> signInWithGoogle() async {
    final signIn = _configuredGoogleSignIn;
    await _googleInitialization;

    try {
      final account = await signIn.authenticate();
      final authentication = account.authentication;
      final idToken = authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw const AuthException('Google ID token alınamadı.');
      }

      final authorization = await account.authorizationClient
          .authorizationForScopes(const <String>[]);
      return NativeAuthCredential.google(
        idToken: idToken,
        accessToken: authorization?.accessToken,
      );
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) return null;
      rethrow;
    }
  }

  @override
  Future<NativeAuthCredential?> signInWithApple() async {
    final client = supabaseClient;
    final rawNonce = client?.auth.generateRawNonce();
    if (rawNonce == null) {
      throw const AuthException('Apple girişi başlatılamadı.');
    }
    final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();

    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: const [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );
      final idToken = credential.identityToken;
      if (idToken == null || idToken.isEmpty) {
        throw const AuthException('Apple ID token alınamadı.');
      }
      return NativeAuthCredential.apple(idToken: idToken, rawNonce: rawNonce);
    } on SignInWithAppleAuthorizationException catch (error) {
      if (error.code == AuthorizationErrorCode.canceled) return null;
      rethrow;
    }
  }
}
