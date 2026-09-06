import 'package:flutter/foundation.dart';

import '../data/zankurd_repository.dart';
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
    this.debugLog,
  });

  final PushTokenSource source;
  final ZanKurdRepository repository;
  final void Function(String message)? debugLog;

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
      if (repository.currentUserId == null) {
        _debug('no session; token was not written');
        return;
      }
      await repository.setFcmToken(token.trim());
    } catch (error, stack) {
      _debug('sync failed');
      ErrorReporter.record(error, stack, reason: 'push_token_sync');
    }
  }
}
