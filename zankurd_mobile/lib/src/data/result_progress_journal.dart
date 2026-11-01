import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Bir sonuç adımının kalıcı hedefleri ve tekrar gösterilecek çıktısı.
class ResultProgressMutation {
  const ResultProgressMutation({required this.values, this.result = const {}});

  final Map<String, Object> values;
  final Map<String, Object?> result;
}

/// Tur adımlarının write-ahead günlüğü. Hedefler delta değildir: yazımın
/// ortasında süreç ölse bile aynı hedefi yeniden yazmak çift kazanım üretmez.
/// Aynı depoda yeni işlem başlamadan önce yarım projeksiyonlar tamamlanır.
class ResultProgressJournal {
  static final Map<String, Future<void>> _queues = {};

  static Future<Map<String, dynamic>> run({
    required SharedPreferences preferences,
    required String namespace,
    required String operationId,
    required ResultProgressMutation Function() prepare,
  }) async {
    if (operationId.trim().isEmpty) throw ArgumentError('Empty operation id');
    final previous = _queues[namespace] ?? Future<void>.value();
    late final Future<void> queued;
    final work = previous.then((_) async {
      await _recoverUnlocked(preferences: preferences, namespace: namespace);
      final prefix = '$namespace.';
      final key = '$prefix${Uri.encodeComponent(operationId)}';
      final existing = preferences.getString(key);
      if (existing != null) {
        return Map<String, dynamic>.from(_decode(existing)['result'] as Map);
      }
      final mutation = prepare();
      final entry = <String, dynamic>{
        'values': mutation.values,
        'result': mutation.result,
        'done': false,
      };
      await _checked(preferences, key, jsonEncode(entry));
      await _apply(preferences, key, entry);
      return Map<String, dynamic>.from(mutation.result);
    });
    queued = work.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    _queues[namespace] = queued;
    try {
      return await work;
    } finally {
      if (identical(_queues[namespace], queued)) _queues.remove(namespace);
    }
  }

  /// Depo yüklenmeden ve günlüksüz mutasyonlardan önce çağrılır.
  static Future<void> recover({
    required SharedPreferences preferences,
    required String namespace,
  }) async {
    final previous = _queues[namespace] ?? Future<void>.value();
    final work = previous.then(
      (_) => _recoverUnlocked(preferences: preferences, namespace: namespace),
    );
    final queued = work.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    _queues[namespace] = queued;
    try {
      await work;
    } finally {
      if (identical(_queues[namespace], queued)) _queues.remove(namespace);
    }
  }

  static Future<void> _recoverUnlocked({
    required SharedPreferences preferences,
    required String namespace,
  }) async {
    final prefix = '$namespace.';
    for (final key
        in preferences
            .getKeys()
            .where((key) => key.startsWith(prefix))
            .toList()) {
      final entry = _decode(preferences.getString(key)!);
      if (entry['done'] != true) await _apply(preferences, key, entry);
    }
  }

  static Map<String, dynamic> _decode(String raw) =>
      Map<String, dynamic>.from(jsonDecode(raw) as Map);

  static Future<void> _apply(
    SharedPreferences preferences,
    String key,
    Map<String, dynamic> entry,
  ) async {
    for (final target in (entry['values'] as Map).entries) {
      await _checked(preferences, target.key as String, target.value as Object);
    }
    // Done ve hedefler aynı kayıtta: done yazılamazsa hedefler tekrar
    // uygulanabilir; başarılı done hiçbir zaman kazanımı tekrar artırmaz.
    await _checked(preferences, key, jsonEncode({...entry, 'done': true}));
  }

  static Future<void> _checked(
    SharedPreferences preferences,
    String key,
    Object value,
  ) async {
    try {
      final bool saved;
      if (value is int) {
        saved = await preferences.setInt(key, value);
      } else if (value is bool) {
        saved = await preferences.setBool(key, value);
      } else if (value is double) {
        saved = await preferences.setDouble(key, value);
      } else if (value is String) {
        saved = await preferences.setString(key, value);
      } else if (value is List) {
        saved = await preferences.setStringList(key, value.cast<String>());
      } else {
        throw ArgumentError('Unsupported journal value: $key');
      }
      if (!saved) throw StateError('Result journal persistence failed: $key');
    } catch (_) {
      // SharedPreferences iyimser cache'i başarısız yazıyı kalıcı sanmasın.
      await preferences.reload();
      rethrow;
    }
  }
}
