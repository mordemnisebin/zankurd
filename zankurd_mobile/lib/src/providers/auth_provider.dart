import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthProvider extends ChangeNotifier {
  final FirebaseAuth? _auth;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  User? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;

  User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _currentUser != null;

  AuthProvider() : _auth = FirebaseAuth.instance {
    _auth!.authStateChanges().listen((User? user) {
      _currentUser = user;
      notifyListeners();
    });
  }

  /// Test constructor — Firebase başlatılmadan kullanım için.
  AuthProvider.test() : _auth = null;

  Future<bool> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final auth = _auth!;
      final credential = await auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      await credential.user?.updateDisplayName(displayName);
      await credential.user?.reload();

      _currentUser = auth.currentUser;
      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _getErrorMessage(e.code);
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Bir hata oluştu: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> signInWithEmail({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final auth = _auth!;
      await auth.signInWithEmailAndPassword(email: email, password: password);
      _currentUser = auth.currentUser;
      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _getErrorMessage(e.code);
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Bir hata oluştu: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> signInWithGoogle() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final auth = _auth!;
      await auth.signInWithCredential(credential);
      _currentUser = auth.currentUser;
      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _getErrorMessage(e.code);
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Google ile giriş başarısız: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> resetPassword(String email) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _auth!.sendPasswordResetEmail(email: email);
      _isLoading = false;
      _errorMessage = null;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _getErrorMessage(e.code);
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Şifre sıfırlama başarısız: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut() async {
    await _auth!.signOut();
    await _googleSignIn.signOut();
    _currentUser = null;
    _errorMessage = null;
    notifyListeners();
  }

  String _getErrorMessage(String code) {
    switch (code) {
      case 'weak-password':
        return 'Parola çok zayıf.';
      case 'email-already-in-use':
        return 'Bu e-posta zaten kullanılıyor.';
      case 'invalid-email':
        return 'Geçersiz e-posta adresi.';
      case 'user-not-found':
        return 'Kullanıcı bulunamadı.';
      case 'wrong-password':
        return 'Yanlış parola.';
      default:
        return 'Bir hata oluştu. Lütfen tekrar deneyin.';
    }
  }
}
