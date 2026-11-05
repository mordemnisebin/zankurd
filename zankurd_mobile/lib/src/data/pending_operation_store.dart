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

  /// Anahtar KAPSAMI da taşır (`<tür>.<kapsam>.<hesap>`; kapsam boşsa eski
  /// `<tür>.<hesap>`). Eskiden yalnız tür+hesap vardı: farklı kategoride
  /// ikinci düello aynı yuvadaki kimliği eziyor, birincinin yeniden denemesi
  /// yeni kimlikle gidip çift düello açıyordu (alan 3 #13). Hesap kimliği
  /// SONDA kalır: hesap silme süpürmesi (`LocalProgressScope`) soneke bakar.
  static String _key(String kind, String ownerId, [String scope = '']) =>
      scope.isEmpty
      ? '$_prefix$kind.$ownerId'
      : '$_prefix$kind.${Uri.encodeComponent(scope)}.$ownerId';

  /// Varsayılan ömür: sunucunun 14 günlük saklamasından bir gün kısa.
  static const defaultMaxAge = Duration(days: 13);

  /// Günlük hak türleri (çark) için kısa ömür.
  static const shortMaxAge = Duration(hours: 24);

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
    // Sunucu işlem kayıtlarını 14 gün tutar (`idempotent_ops` temizliği);
    // kimlik yalnız KESİN yanıtta silinir. Ömür sunucu saklamasından KISA
    // kalmalı ama ödeme/oluşturma türünde ondan çok önce bitmemeli: 24 saat
    // sonra yeni kimlikle gelen belirsiz alım çift tahsil ederdi (Copilot,
    // W3 turu 2). Günlük hak gibi "dünkü sonucu bugüne taşımayan" türler
    // kısa ömrü AÇIKÇA verir (bkz. `shortMaxAge`).
    Duration maxAge = defaultMaxAge,
    DateTime? now,
  }) {
    final lockKey = _key(kind, ownerId, scope);
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
    final key = _key(kind, ownerId, scope);
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
    // Build 45'in KAPSAMSIZ anahtarı (`<tür>.<hesap>`): kapsam kaydın içinde
    // durur. Aynı kapsamdaysa bekleyen kimlik yeni anahtara TAŞINIR; yoksa
    // güncelleme sonrası yeniden deneme yeni kimlikle gidip çift düello
    // açardı. Başka kapsama ait eski kayıt yerinde bırakılır.
    if (scope.isNotEmpty) {
      final legacyKey = _key(kind, ownerId);
      final legacyRaw = preferences.getString(legacyKey);
      if (legacyRaw != null) {
        try {
          final entry = jsonDecode(legacyRaw);
          if (entry is Map &&
              entry['id'] is String &&
              isClientRoundId(entry['id'] as String) &&
              entry['scope'] == scope &&
              entry['at'] is int) {
            final age = at.millisecondsSinceEpoch - (entry['at'] as int);
            if (age >= 0 && age <= maxAge.inMilliseconds) {
              if (await preferences.setString(key, legacyRaw) &&
                  preferences.getString(key) == legacyRaw) {
                await preferences.remove(legacyKey);
                return entry['id'] as String;
              }
            }
          }
        } catch (error, stack) {
          ErrorReporter.record(error, stack, reason: 'pending_op_legacy');
        }
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

  /// Bekleyen kimlik VARSA (geçerli, süresi dolmamış) döndürür; YOKSA üretmez.
  /// Açılış kurtarması "yarım kalmış bir işlem var mı" diye bakar.
  static Future<String?> peek(
    String kind,
    String ownerId, {
    String scope = '',
    Duration maxAge = defaultMaxAge,
    DateTime? now,
  }) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final raw = preferences.getString(_key(kind, ownerId, scope));
      if (raw == null) return null;
      final entry = jsonDecode(raw);
      if (entry is Map &&
          entry['id'] is String &&
          isClientRoundId(entry['id'] as String) &&
          entry['scope'] == scope &&
          entry['at'] is int) {
        final age =
            (now ?? DateTime.now()).millisecondsSinceEpoch -
            (entry['at'] as int);
        if (age >= 0 && age <= maxAge.inMilliseconds) {
          return entry['id'] as String;
        }
      }
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'pending_op_peek');
    }
    return null;
  }

  /// Kesin yanıt (başarı ya da kesin ret) alındı: kimliği bırak. Silme
  /// kabul edilmediyse (disk yazım hatası) kimlik ÖLÜ işaretle ezilir; eskiden
  /// sonuç denetlenmiyor, silinmiş sanılan kimlik 24 saat içinde aynı
  /// kategoride yeniden kullanılıp tamamlanmış işlemi geri getiriyordu
  /// (alan 3 #14). Döner: kimlik artık kullanılamaz mı.
  static Future<bool> clear(
    String kind,
    String ownerId, {
    String scope = '',
  }) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final key = _key(kind, ownerId, scope);
      if (await preferences.remove(key)) return true;
      await preferences.reload();
      if (await preferences.remove(key)) return true;
      final dead = await preferences.setString(
        key,
        jsonEncode({'cleared': true}),
      );
      if (!dead) {
        ErrorReporter.record(
          StateError('Pending operation id could not be cleared.'),
          StackTrace.current,
          reason: 'pending_op_clear',
        );
      }
      return dead;
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'pending_op_clear');
      return false;
    }
  }
}
