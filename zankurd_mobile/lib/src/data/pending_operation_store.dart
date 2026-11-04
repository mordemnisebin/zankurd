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

  /// [kind] + [ownerId] için bekleyen kimliği döndürür; yoksa, süresi
  /// dolmuşsa ya da [scope] değişmişse yenisini üretip KALICI yazar.
  static Future<String> idFor(
    String kind,
    String ownerId, {
    String scope = '',
    Duration maxAge = const Duration(hours: 24),
    DateTime? now,
  }) async {
    final at = now ?? DateTime.now();
    SharedPreferences? preferences;
    try {
      preferences = await SharedPreferences.getInstance();
      final raw = preferences.getString(_key(kind, ownerId));
      if (raw != null) {
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
      }
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'pending_op_read');
    }
    final id = newClientRoundId();
    try {
      await preferences?.setString(
        _key(kind, ownerId),
        jsonEncode({'id': id, 'scope': scope, 'at': at.millisecondsSinceEpoch}),
      );
    } catch (error, stack) {
      // Yazılamadıysa bu çağrı yine de kimlikle gider (bu oturumdaki yeniden
      // deneme aynı kimliği bulamaz; yalnız uygulama-kapanması örtüsü zayıflar).
      ErrorReporter.record(error, stack, reason: 'pending_op_write');
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
