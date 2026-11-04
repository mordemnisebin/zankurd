import 'dart:async';

import 'package:flutter/foundation.dart';

import '../config/feature_flags.dart';
import '../data/zankurd_repository.dart';
import '../providers/repository_holder.dart';
import '../utils/error_reporter.dart';

/// Cihazın FCM token'ını üretir. Testlerde sahte kaynak bağlanır;
/// Firebase yoksa [NoopPushTokenSource] sessizce boş döner.
abstract class PushTokenSource {
  Future<String?> currentToken();
}

/// Yenilenen cihaz token'larını sunan kaynak. Token üretmeyen kaynakların
/// bir akış oluşturması gerekmez.
abstract interface class PushTokenRefreshSource {
  Stream<String> get onTokenRefresh;
}

class NoopPushTokenSource implements PushTokenSource {
  const NoopPushTokenSource();

  @override
  Future<String?> currentToken() async => null;
}

/// Token'ı [set_fcm_token] RPC'sine yazar. Gönderi sunucu kuyruğundadır.
class PushTokenSync {
  const PushTokenSync({
    required this.source,
    required this.repository,
    this.repositoryHolder,
    this.debugLog,
    this.remoteEnabled,
  });

  // Bütün kabuk/kaynak örnekleri aynı cihaz token'ını kaydeder. Çıkış
  // bariyeri eski okumaları geçersiz kılar ve başlamış RPC'leri temizleme
  // işleminden önce bitirir; geç kalan kayıt eski hesabı yeniden bağlayamaz.
  static int _sessionEpoch = 0;
  static int _suspended = 0;
  static int _nextRequest = 0;
  static int _latestRequest = 0;
  static Future<void>? _writeTail;

  /// [waitForPendingWrites] yalnız sunucuda hesap zaten silinmişse false
  /// olur: token RPC yalnız UPDATE yapar, silinen profili yeniden yaratamaz.
  static Future<T> suspendRegistrationsDuring<T>(
    Future<T> Function() action, {
    bool waitForPendingWrites = true,
  }) async {
    _sessionEpoch++;
    _suspended++;
    try {
      // Timeout RPC'yi iptal etmiş sayılmaz: süre aşılırsa action hiç
      // çalışmaz ve mevcut oturum korunur. Kullanıcı yeniden deneyebilir.
      final pendingWrite = _writeTail;
      if (waitForPendingWrites && pendingWrite != null) {
        await pendingWrite.timeout(const Duration(seconds: 5));
      }
      return await action();
    } finally {
      _suspended--;
    }
  }

  final PushTokenSource source;

  /// Açılış deposu — [repositoryHolder] yoksa bu kullanılır.
  final ZanKurdRepository repository;

  /// Geç kurtarmada depo bu nesne üzerinden değişir (bkz. [RepositoryHolder]).
  /// Varsa token YENİ depoya yazılır; yoksa ilk değerine takılı kalırdı.
  final RepositoryHolder? repositoryHolder;

  final void Function(String message)? debugLog;

  /// Uzak anahtar (push_v2_enabled). Kapalıyken jeton HİÇBİR yolla yazılmaz:
  /// açılış, yeniden bağlanma, öne gelme, jeton yenileme ve oturum açma
  /// hepsi [_sync]'ten geçer; anahtar tek bir çağrı yerinde değil burada
  /// denetlenir. Testler sahte bir kapı verir.
  final bool Function()? remoteEnabled;

  bool get _gateOpen => (remoteEnabled ?? () => FeatureGate.pushV2)();

  ZanKurdRepository get _repository =>
      repositoryHolder?.repository ?? repository;

  void _debug(String message) {
    if (!kDebugMode) return;
    (debugLog ?? debugPrint)('[push-token] $message');
  }

  /// Aboneliğin ömrünü kabuk yönetir; kapanırken iptal eder. SDK açılışta
  /// APNs token'ını henüz alamadıysa sonraki FCM yenilemesi kaydı tamamlar.
  StreamSubscription<String>? watchTokenRefresh() {
    if (kIsWeb) return null;
    final tokenSource = source;
    if (tokenSource is! PushTokenRefreshSource) return null;
    try {
      return (tokenSource as PushTokenRefreshSource).onTokenRefresh.listen(
        (token) => unawaited(_sync(refreshedToken: token)),
        onError: (Object error, StackTrace stack) =>
            ErrorReporter.record(error, stack, reason: 'push_token_refresh'),
      );
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'push_token_refresh');
      return null;
    }
  }

  Future<void> sync() => _sync();

  // Yenileme olayı tokenı zaten taşır. Yeniden getToken çağırmak, SDK'nın
  // bağımsız APNs/platform okuması henüz hazır değilse bu kaydı kaybettirir.
  Future<void> _sync({String? refreshedToken}) async {
    if (kIsWeb || _suspended > 0) return;
    if (!_gateOpen) {
      _debug('push_v2 disabled remotely; token was not written');
      return;
    }
    final epoch = _sessionEpoch;
    final request = ++_nextRequest;
    try {
      final repository = _repository;
      final userId = repository.currentUserId;
      if (userId == null) {
        _debug('no session; token was not written');
        return;
      }
      final token = refreshedToken ?? await source.currentToken();
      if (token == null || token.trim().isEmpty) {
        _debug('no token; native APNs/FCM token is unavailable');
        return;
      }
      bool isSessionCurrent() =>
          _suspended == 0 &&
          epoch == _sessionEpoch &&
          identical(repository, _repository) &&
          repository.currentUserId == userId;
      if (!isSessionCurrent() || request < _latestRequest) {
        _debug(
          'session changed or newer token available; token was not written',
        );
        return;
      }
      // Yeni bir okuma null/hata/bekleme durumundayken eldeki geçerli token
      // sıradan çıkarılmaz. Yalnız kullanılabilir yeni sonuç eskisini geçersiz kılar.
      _latestRequest = request;
      bool isCurrent() => isSessionCurrent() && request == _latestRequest;
      final write = (_writeTail ?? Future<void>.value()).then((_) async {
        if (isCurrent()) await repository.setFcmToken(token.trim());
      });
      // Bir RPC hatası sonraki kaydı veya çıkış bariyerini kilitlemez.
      final settled = write.then<void>(
        (_) {},
        onError: (Object _, StackTrace _) {},
      );
      _writeTail = settled;
      try {
        await write;
      } finally {
        if (identical(_writeTail, settled)) _writeTail = null;
      }
    } catch (error, stack) {
      _debug('sync failed');
      ErrorReporter.record(error, stack, reason: 'push_token_sync');
    }
  }
}
