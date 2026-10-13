import 'dart:async';

import '../utils/error_reporter.dart';
import 'sync_manager.dart';
import 'zankurd_repository.dart';

/// Turnuva aşamasını sunucuya bırakır.
///
/// Çağrılar sıraya girer. Onaylanmayan yazım kuyrukta yalnız son aşama
/// olarak durur; daha eski aşama yeniden yazılmaz.
class TournamentProgressPublisher {
  TournamentProgressPublisher._();

  static Future<void> _tail = Future<void>.value();

  static Future<void> publish({
    required ZanKurdRepository repository,
    required String stage,
    required int userScore,
    required int opponentScore,
    required List<String> botWinners,
  }) {
    final done = Completer<void>();
    final previous = _tail;
    _tail = done.future;
    return previous.then((_) async {
      try {
        var acknowledged = false;
        try {
          acknowledged = await repository.saveTournamentProgress(
            stage,
            userScore,
            opponentScore,
            botWinners,
          );
        } catch (error, stack) {
          ErrorReporter.record(
            error,
            stack,
            reason: 'tournament_progress_publish',
          );
        }
        final manager = SyncManager.maybeInstance;
        if (manager == null) return;
        try {
          await manager.retainLatestTournamentProgress(
            acknowledged: acknowledged,
            stage: stage,
            userScore: userScore,
            opponentScore: opponentScore,
            botWinners: botWinners,
          );
        } catch (error, stack) {
          ErrorReporter.record(
            error,
            stack,
            reason: 'tournament_progress_queue',
          );
        }
      } finally {
        done.complete();
      }
    });
  }
}
