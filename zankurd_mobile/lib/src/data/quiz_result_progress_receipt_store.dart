import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Sonuç teslimatının kalıcı aşamaları.
///
/// Eskiden burada tek bir `processing` vardı ve altı ayrı adımın hepsini
/// temsil ediyordu: dondurma teklifi, kullanıcı kararı, coin harcama,
/// dondurmanın uygulanması, yerel ilerleme yazımı ve sunucu onayı. Süreç
/// ölünce hangisinin çalıştığı bilinemiyor, bu yüzden hiçbiri bir daha
/// çalıştırılamıyordu — makbuz kalıcı olarak kilitleniyordu.
///
/// Aşamaları ayırmanın tek amacı budur: yeniden açılışta "ne yapılabilir"
/// sorusunun cevabı belirli olsun.
enum QuizResultReceiptStage {
  /// Dondurma teklifi gösterilmeli; kullanıcı henüz cevaplamadı.
  ///
  /// Bu aşamada HİÇBİR yan etki oluşmamıştır — coin harcanmamış, seri
  /// değişmemiştir. Bu yüzden kesintiden sonra soruyu yeniden sormak
  /// güvenlidir ve kullanıcının kararı kaybolmaz.
  pendingUserDecision,

  /// Karar alındı ve diske yazıldı; henüz uygulanmadı.
  decisionRecorded,

  /// `spend_coins` isteği gönderildi, sonucu bilinmiyor.
  ///
  /// Bu aşama ASLA otomatik yeniden çalıştırılmaz: `spend_coins` sunucuda
  /// idempotent değildir (`streak_freeze` için hiçbir dedup anahtarı yok,
  /// her çağrı yeni bir `-50` satırı yazar). Kesintiden sonra ileri
  /// çözülür — coin bir daha harcanmaz.
  freezeApplying,

  /// Dondurma uygulandı.
  freezeApplied,

  /// Dondurma yapılmadı: kullanıcı istemedi, bakiye yetmedi, hata oldu ya
  /// da kesinti sonrası güvenli tarafa çözüldü.
  freezeSkipped,

  /// Otomatik yerel ilerleme yazımı sürüyor.
  ///
  /// Yerel depolar (XP, rozet, ustalık, görev) idempotent değildir, bu
  /// yüzden kesilen bir yazım da yeniden çalıştırılmaz. Aradaki fark
  /// şudur: artık ileri çözülür, sonsuza dek kilitlenmez.
  progressApplying,

  /// Yerel ilerleme yazımı bitti.
  progressApplied,

  /// Sunucu onayı bekleniyor.
  ///
  /// Tek gerçekten yeniden denenebilir adım budur ve olabilmesinin sebebi
  /// sunucudur: `room_result_receipts` birincil anahtarı
  /// `(room_id, player_id)`, yani `acknowledge_room_result` idempotenttir.
  acknowledgementPending,

  /// Teslimat tamamlandı.
  completed,
}

/// [QuizResultProgressReceiptStore] çağrısının otomatik adım için sonucu.
enum QuizResultProgressReceiptOutcome {
  /// Adım bu çağrıda çalıştırıldı.
  executed,

  /// Adım daha önce tamamlanmıştı; tekrar çalıştırılmadı.
  skippedCompleted,

  /// Adımın önceki çalıştırması kesildi. Tekrar çalıştırılmadı — fakat
  /// akış ileri taşındı, kilitlenmedi.
  ///
  /// Ad geriye dönük uyumluluk için korunuyor; anlamı artık "belirsiz ve
  /// sonsuza dek kilitli" değil, "belirsiz olduğu için atlandı".
  blockedProcessing,
}

/// Sonuç teslimatının kalıcı durumu.
class QuizResultReceipt {
  const QuizResultReceipt({required this.stage, this.freezeRequested = false});

  final QuizResultReceiptStage stage;

  /// Kullanıcı dondurmayı seçti mi. Karar, uygulanmadan ÖNCE yazılır ki
  /// coin harcama ile kararın kendisi aynı kesintide birlikte kaybolmasın.
  final bool freezeRequested;

  bool get isTerminal => stage == QuizResultReceiptStage.completed;

  Map<String, Object?> toJson() => {
    'v': 2,
    'stage': stage.name,
    if (freezeRequested) 'freeze': true,
  };

  /// Diskteki değeri çözer.
  ///
  /// v1 kayıtları düz metindi (`processing` / `completed`). `processing`
  /// olanlar tam olarak bu dosyanın düzelttiği kilitli makbuzlardır:
  /// hangi adımın çalıştığı bilinemez, bu yüzden hiçbir yan etkili adım
  /// tekrarlanmaz — fakat onay aşamasına geçilir ki kurtarma ekranı
  /// tekrarlamayı bıraksın.
  static QuizResultReceipt? decode(String? raw) {
    if (raw == null) return null;
    final value = raw.trim();
    if (value.isEmpty) return null;

    if (value == 'completed') {
      return const QuizResultReceipt(stage: QuizResultReceiptStage.completed);
    }
    if (value == 'processing') {
      return const QuizResultReceipt(
        stage: QuizResultReceiptStage.progressApplying,
      );
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(value);
    } on FormatException {
      throw FormatException('Bilinmeyen sonuç ilerleme makbuzu durumu: $value');
    }
    if (decoded is! Map<String, Object?>) {
      throw FormatException('Bilinmeyen sonuç ilerleme makbuzu durumu: $value');
    }
    final stageName = decoded['stage'];
    final stage = QuizResultReceiptStage.values
        .where((candidate) => candidate.name == stageName)
        .firstOrNull;
    if (stage == null) {
      throw FormatException('Bilinmeyen sonuç ilerleme makbuzu durumu: $value');
    }
    return QuizResultReceipt(
      stage: stage,
      freezeRequested: decoded['freeze'] == true,
    );
  }
}

class QuizResultProgressReceiptStore {
  QuizResultProgressReceiptStore(this._preferences);

  static const _keyPrefix = 'zankurd.quiz_result_progress_receipt.';
  static final Map<String, Future<QuizResultProgressReceiptOutcome>> _inFlight =
      {};
  static final Set<String> _cacheUncertain = {};

  final SharedPreferences _preferences;

  /// Test yalıtımı: süreç ölümünü taklit eden testler, bir önceki koşumun
  /// bellek içi izini görmemeli.
  static void debugResetInFlight() {
    _inFlight.clear();
    _cacheUncertain.clear();
  }

  static String keyFor({required String userId, required String roomId}) =>
      '$_keyPrefix${userId.trim()}:${roomId.trim()}';

  /// Kalıcı durumu okur. Kayıt yoksa `null`.
  Future<QuizResultReceipt?> read({
    required String userId,
    required String roomId,
  }) async {
    final key = _validatedKey(userId, roomId);
    if (_cacheUncertain.contains(key)) {
      await _preferences.reload();
      _cacheUncertain.remove(key);
    }
    return QuizResultReceipt.decode(_preferences.getString(key));
  }

  /// Durumu ilerletir.
  Future<void> write({
    required String userId,
    required String roomId,
    required QuizResultReceipt receipt,
  }) async {
    await _persist(_validatedKey(userId, roomId), receipt);
  }

  /// Otomatik ilerleme adımını en fazla bir kez çalıştırır.
  ///
  /// [action] yalnız otomatik ve yan etkileri yerel olan adımları
  /// içermelidir. Kullanıcı girdisi bekleyen hiçbir şey buraya girmez —
  /// dondurma kararı bu kritik bölümün DIŞINDA, kendi aşamalarıyla
  /// alınır.
  Future<QuizResultProgressReceiptOutcome> runOnce({
    required String userId,
    required String roomId,
    required Future<void> Function() action,
  }) {
    final key = _validatedKey(userId, roomId);
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

    final receipt = QuizResultReceipt.decode(_preferences.getString(key));
    switch (receipt?.stage) {
      case QuizResultReceiptStage.completed:
      case QuizResultReceiptStage.progressApplied:
      case QuizResultReceiptStage.acknowledgementPending:
        return QuizResultProgressReceiptOutcome.skippedCompleted;

      // Yazım yarıda kesilmiş. Yerel depolar idempotent olmadığı için
      // tekrar çalıştırmak XP'yi ve rozeti ikiye katlar; atlanır. Fark
      // şurada: akış ileri taşınır, böylece onay yapılabilir ve kurtarma
      // ekranı tekrarlamayı bırakır.
      case QuizResultReceiptStage.progressApplying:
        return QuizResultProgressReceiptOutcome.blockedProcessing;

      case null:
      case QuizResultReceiptStage.pendingUserDecision:
      case QuizResultReceiptStage.decisionRecorded:
      case QuizResultReceiptStage.freezeApplying:
      case QuizResultReceiptStage.freezeApplied:
      case QuizResultReceiptStage.freezeSkipped:
        break;
    }

    await _persist(
      key,
      const QuizResultReceipt(stage: QuizResultReceiptStage.progressApplying),
    );
    await action();
    await _persist(
      key,
      const QuizResultReceipt(
        stage: QuizResultReceiptStage.acknowledgementPending,
      ),
    );
    return QuizResultProgressReceiptOutcome.executed;
  }

  String _validatedKey(String userId, String roomId) {
    final normalizedUserId = userId.trim();
    final normalizedRoomId = roomId.trim();
    if (normalizedUserId.isEmpty) {
      throw ArgumentError.value(userId, 'userId', 'Boş olamaz.');
    }
    if (normalizedRoomId.isEmpty) {
      throw ArgumentError.value(roomId, 'roomId', 'Boş olamaz.');
    }
    return '$_keyPrefix$normalizedUserId:$normalizedRoomId';
  }

  Future<void> _persist(String key, QuizResultReceipt receipt) async {
    final encoded = jsonEncode(receipt.toJson());
    try {
      final saved = await _preferences.setString(key, encoded);
      if (!saved) {
        throw StateError(
          'Sonuç ilerleme makbuzu kalıcı yazılamadı: ${receipt.stage.name}',
        );
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
