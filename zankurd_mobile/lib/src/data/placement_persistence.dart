import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'local_progress_write_lock.dart';

typedef PersistedPlacement = ({String? level, bool skipped, int? updatedAt});

/// Üç eski anahtar korunur; pending kaydı silinene dek okuyucular önceki
/// durumu görür. Böylece yarım yazım uygulama yeniden açılınca da başarı olmaz.
class PlacementPersistence {
  PlacementPersistence._();

  static const _prefix = 'zankurd.placement.v1.';
  static String key(String field) =>
      LocalProgressWriteLock.physical('$_prefix$field');
  static Future<void>? _tail;
  static final Map<String, PersistedPlacement> _writing = {};

  static PersistedPlacement read(SharedPreferences prefs) => _read(prefs, key);

  static PersistedPlacement _read(
    SharedPreferences prefs,
    String Function(String) key,
  ) {
    final writing = _writing[key('pending')];
    if (writing != null) return writing;
    final pending = prefs.getString(key('pending'));
    if (pending != null) {
      final previous = jsonDecode(pending) as Map<String, dynamic>;
      return (
        level: previous['level'] as String?,
        skipped: previous['skipped'] as bool,
        updatedAt: previous['updatedAt'] as int?,
      );
    }
    return (
      level: prefs.getString(key('level')),
      skipped: prefs.getBool(key('skipped')) ?? false,
      updatedAt: prefs.getInt(key('updatedAt')),
    );
  }

  static Future<void> write(
    SharedPreferences prefs,
    PersistedPlacement value,
  ) async {
    // Oturum ve eşitleme değişimleri await sırasında hedef kapsamı değiştiremez.
    final keys = {
      for (final field in ['level', 'skipped', 'updatedAt', 'pending'])
        field: key(field),
    };
    String scopedKey(String field) => keys[field]!;
    final previousWrite = _tail;
    final release = Completer<void>();
    _tail = release.future;
    if (previousWrite != null) await previousWrite;
    var cacheResolved = false;
    try {
      if (_writing.containsKey(scopedKey('pending'))) {
        // Önceki hata sonrası reload da başarısızsa önbellek güvenilmez.
        // Yeni yazımdan önce diski okumadan korunan eski görünümü bırakma.
        await prefs.reload();
        _writing.remove(scopedKey('pending'));
      }
      final before = _read(prefs, scopedKey);
      _writing[scopedKey('pending')] = before;
      Future<void> checked(Future<bool> write) async {
        if (!await write) {
          throw StateError('Placement state was not persisted.');
        }
      }

      await checked(
        prefs.setString(
          scopedKey('pending'),
          jsonEncode({
            'level': before.level,
            'skipped': before.skipped,
            'updatedAt': before.updatedAt,
          }),
        ),
      );
      await checked(
        value.level == null
            ? prefs.remove(scopedKey('level'))
            : prefs.setString(scopedKey('level'), value.level!),
      );
      await checked(
        value.skipped
            ? prefs.setBool(scopedKey('skipped'), true)
            : prefs.remove(scopedKey('skipped')),
      );
      await checked(
        value.updatedAt == null
            ? prefs.remove(scopedKey('updatedAt'))
            : prefs.setInt(scopedKey('updatedAt'), value.updatedAt!),
      );
      await checked(prefs.remove(scopedKey('pending')));
      cacheResolved = true;
    } catch (_) {
      // set/remove, platform false döndürse bile iyimser önbelleği değiştirir.
      await prefs.reload();
      cacheResolved = true;
      rethrow;
    } finally {
      if (cacheResolved) _writing.remove(scopedKey('pending'));
      release.complete();
      // Biten yazımın zone’unu boş kuyrukta tutma; bekleyen varsa onun
      // kuyruğunu koru.
      if (identical(_tail, release.future)) _tail = null;
    }
  }
}
