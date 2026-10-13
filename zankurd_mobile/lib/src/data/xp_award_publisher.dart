import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/error_reporter.dart';
import 'durable_write.dart';
import 'sync_manager.dart';
import 'xp_store.dart';
import 'zankurd_repository.dart';

/// Rekabetçi oda XP yazımını sunucuya bırakır.
///
/// Solo/öğrenme/görev XP'si cihazdaki öğrenme ilerlemesidir ve istemcinin
/// hesapladığı delta rekabetçi `profiles.xp` alanına gönderilmez. Oda XP'si
/// ise bitmiş oda skorundan `award_room_xp` tarafından sunucuda hesaplanır.
class XpAwardPublisher {
  const XpAwardPublisher._();

  static Future<void> publish({
    required ZanKurdRepository repository,
    required int delta,
    String? roomId,
  }) async {
    final room = roomId?.trim() ?? '';
    if (room.isEmpty) return;
    try {
      final total = await repository.awardRoomXp(room);
      if (!repository.xpAwardIsServerTotal) return;
      final store = await XPStore.load();
      await store.applyServerTotal(total);
    } on RetryableWriteException catch (error, stack) {
      await _queue(roomId: room, error: error.cause, stack: stack);
    } on PostgrestException catch (error, stack) {
      if (error.code == '42883') {
        ErrorReporter.record(error, stack, reason: 'xp award not queued');
        return;
      }
      await _queue(roomId: room, error: error, stack: stack);
    } catch (error, stack) {
      await _queue(roomId: room, error: error, stack: stack);
    }
  }

  static Future<void> _queue({
    required String roomId,
    required Object error,
    required StackTrace stack,
  }) async {
    final manager = SyncManager.maybeInstance;
    if (manager == null) {
      ErrorReporter.record(error, stack, reason: 'xp award queue unavailable');
      return;
    }
    try {
      await manager.queueXpAward(roomId: roomId);
    } catch (queueError, queueStack) {
      ErrorReporter.record(
        queueError,
        queueStack,
        reason: 'xp award queue rejected',
      );
    }
  }
}
