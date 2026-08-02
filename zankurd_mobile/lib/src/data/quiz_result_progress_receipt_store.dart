import 'package:shared_preferences/shared_preferences.dart';

enum QuizResultProgressReceiptOutcome {
  executed,
  skippedCompleted,
  recoveredProcessing,
}

class QuizResultProgressReceiptStore {
  QuizResultProgressReceiptStore(this._preferences);

  static const _keyPrefix = 'zankurd.quiz_result_progress_receipt.';
  static const _processing = 'processing';
  static const _completed = 'completed';
  static final Map<String, Future<QuizResultProgressReceiptOutcome>> _inFlight =
      {};
  static final Set<String> _cacheUncertain = {};

  final SharedPreferences _preferences;

  Future<QuizResultProgressReceiptOutcome> runOnce({
    required String userId,
    required String roomId,
    required Future<void> Function() action,
  }) {
    final normalizedUserId = userId.trim();
    final normalizedRoomId = roomId.trim();
    if (normalizedUserId.isEmpty) {
      throw ArgumentError.value(userId, 'userId', 'Boş olamaz.');
    }
    if (normalizedRoomId.isEmpty) {
      throw ArgumentError.value(roomId, 'roomId', 'Boş olamaz.');
    }

    final key = '$_keyPrefix$normalizedUserId:$normalizedRoomId';
    final existing = _inFlight[key];
    if (existing != null) return existing;

    late final Future<QuizResultProgressReceiptOutcome> tracked;
    tracked = _run(key, action).whenComplete(() {
      if (identical(_inFlight[key], tracked)) {
        _inFlight.remove(key);
      }
    });
    _inFlight[key] = tracked;
    return tracked;
  }

  Future<QuizResultProgressReceiptOutcome> _run(
    String key,
    Future<void> Function() action,
  ) async {
    if (_cacheUncertain.contains(key)) {
      await _preferences.reload();
      _cacheUncertain.remove(key);
    }

    final state = _preferences.getString(key);
    if (state == _completed) {
      return QuizResultProgressReceiptOutcome.skippedCompleted;
    }
    if (state == _processing) {
      await _persist(key, _completed);
      return QuizResultProgressReceiptOutcome.recoveredProcessing;
    }
    if (state != null) {
      throw FormatException('Bilinmeyen sonuç ilerleme makbuzu durumu: $state');
    }

    await _persist(key, _processing);
    await action();
    await _persist(key, _completed);
    return QuizResultProgressReceiptOutcome.executed;
  }

  Future<void> _persist(String key, String state) async {
    try {
      final saved = await _preferences.setString(key, state);
      if (!saved) {
        throw StateError('Sonuç ilerleme makbuzu kalıcı yazılamadı: $state');
      }
    } catch (error, stackTrace) {
      try {
        await _preferences.reload();
        _cacheUncertain.remove(key);
      } catch (_) {
        _cacheUncertain.add(key);
        // Cache uzlaştırma hatası, asıl kalıcılık hatasını maskelememeli.
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
  }
}
