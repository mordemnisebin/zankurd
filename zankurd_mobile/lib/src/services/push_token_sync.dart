import 'package:flutter/foundation.dart';

import '../data/zankurd_repository.dart';
import '../providers/repository_holder.dart';
import '../utils/error_reporter.dart';

/// Cihazın FCM token'ını üretir. Testlerde sahte kaynak bağlanır;
/// Firebase yoksa [NoopPushTokenSource] sessizce boş döner.
abstract class PushTokenSource {
  Future<String?> currentToken();
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
  });

  final PushTokenSource source;

  /// Açılış deposu — [repositoryHolder] yoksa bu kullanılır.
  final ZanKurdRepository repository;

  /// Geç kurtarmada depo bu nesne üzerinden değişir (bkz. [RepositoryHolder]).
  /// Varsa token YENİ depoya yazılır; yoksa ilk değerine takılı kalırdı.
  final RepositoryHolder? repositoryHolder;

  final void Function(String message)? debugLog;

  ZanKurdRepository get _repository =>
      repositoryHolder?.repository ?? repository;

  void _debug(String message) {
    if (!kDebugMode) return;
    (debugLog ?? debugPrint)('[push-token] $message');
  }

  Future<void> sync() async {
    if (kIsWeb) return;
    try {
      final token = await source.currentToken();
      if (token == null || token.trim().isEmpty) {
        _debug('no token; native APNs/FCM token is unavailable');
        return;
      }
      if (_repository.currentUserId == null) {
        _debug('no session; token was not written');
        return;
      }
      await _repository.setFcmToken(token.trim());
    } catch (error, stack) {
      _debug('sync failed');
      ErrorReporter.record(error, stack, reason: 'push_token_sync');
    }
  }
}
