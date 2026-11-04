import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../utils/client_round_id.dart';
import '../utils/error_reporter.dart';

/// Sunucuya giden para/ödül/oluşturma işlemlerinin KALICI işlem kimliği.
///
/// Kusur: yanıtı kaybolan ama sunucuda işlenmiş çağrı (çark dönüşü, düello
/// oluşturma) yeniden denemede YENİ bir işlem sayılıyordu: günlük çarkın
/// tekrarı satın alınmış ek hakkı yakıyor, düello tekrarı ikinci düello
/// açıyordu. Kimlik çağrıdan ÖNCE yazılır (uygulama çağrı sürerken kapansa
/// da yeniden açılışta aynı kimlik gider), yeniden denemede AYNEN kullanılır
/// ve YALNIZ kesin yanıtta ([clear]) silinir. Taşıma hatasında ve belirsiz
/// her durumda kimlik kalır; sunucu aynı kimliği ikinci kez görürse önceki
/// sonucu döndürür, yeni etki üretmez.
///
/// Kimliğin ömrü sınırlıdır ([maxAge]): çok eski bir kimlik, kullanıcının
/// artık hatırlamadığı bir işlemi canlandırmasın. Kapsam ([scope]) farklıysa
/// (başka kategori, başka arkadaş) yeni kimlik üretilir.
class PendingOperationStore {
  const PendingOperationStore._();

  static const _prefix = 'zankurd.pendingOp.';

  static String _key(String kind, String ownerId) => '$_prefix$kind.$ownerId';

  static final Map<String, Future<String>> _inFlight = {};

  /// [kind] + [ownerId] için bekleyen kimliği döndürür; yoksa, süresi
  /// dolmuşsa ya da [scope] değişmişse yenisini üretip KALICI yazar.
  ///
  /// Aynı (tür, hesap) için eşzamanlı ilk çağrılar TEK kimlik üretir (çağrılar
  /// sıraya girer; yoksa iki çağrı farklı kimlik yazıp ikisi de sunucuya
  /// giderdi). Kimlik YAZILAMADIYSA ya da geri okunamadıysa [StateError]
  /// fırlatır: yan etkili RPC kimliği kalıcı olmadan ÇAĞRILMAZ (çağıran mevcut
  /// "kaydedilemedi" hata yoluna düşer).
  static Future<String> idFor(
    String kind,
    String ownerId, {
    String scope = '',
    Duration maxAge = const Duration(hours: 24),
    DateTime? now,
  }) {
    final lockKey = _key(kind, ownerId);
    final previous = _inFlight[lockKey];
    final Future<String> run;
    if (previous == null) {
      run = _resolve(kind, ownerId, scope, maxAge, now);
    } else {
      run = previous
          .then<void>((_) {}, onError: (Object _) {})
          .then((_) => _resolve(kind, ownerId, scope, maxAge, now));
    }
    _inFlight[lockKey] = run;
    return run.whenComplete(() {
      if (identical(_inFlight[lockKey], run)) _inFlight.remove(lockKey);
    });
  }

  static Future<String> _resolve(
    String kind,
    String ownerId,
    String scope,
    Duration maxAge,
    DateTime? now,
  ) async {
    final at = now ?? DateTime.now();
    final key = _key(kind, ownerId);
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(key);
    if (raw != null) {
      try {
        final entry = jsonDecode(raw);
        if (entry is Map &&
            entry['id'] is String &&
            isClientRoundId(entry['id'] as String) &&
            entry['scope'] == scope &&
            entry['at'] is int) {
          final age = at.millisecondsSinceEpoch - (entry['at'] as int);
          if (age >= 0 && age <= maxAge.inMilliseconds) {
            return entry['id'] as String;
          }
        }
      } catch (error, stack) {
        ErrorReporter.record(error, stack, reason: 'pending_op_read');
      }
    }
    final id = newClientRoundId();
    final encoded = jsonEncode({
      'id': id,
      'scope': scope,
      'at': at.millisecondsSinceEpoch,
    });
    final written = await preferences.setString(key, encoded);
    if (!written || preferences.getString(key) != encoded) {
      throw StateError('Pending operation id could not be persisted.');
    }
    return id;
  }

  /// Kesin yanıt (başarı ya da kesin ret) alındı: kimliği bırak.
  static Future<void> clear(String kind, String ownerId) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.remove(_key(kind, ownerId));
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'pending_op_clear');
    }
  }
}
