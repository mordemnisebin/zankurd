import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'checked_preferences_removal.dart';
import 'local_progress_scope.dart';
import 'progress_sync.dart';

import '../utils/error_reporter.dart';

/// Hikâye ilerlemesini (mevcut düğüm id'si) yerelde tutar; devam etme ve
/// yeniden başlatmayı destekler. `SharedPreferences` yoksa bellek-içi çalışır.
class StoryProgressStore {
  StoryProgressStore._(
    this._preferences,
    this._nodes,
    this._at,
    this._done,
    this._paths,
  );

  static String get _prefix => LocalProgressScope.physical('zankurd.story.');

  /// Zaman damgaları ve "bitirildi" kümesi tek JSON anahtarında:
  /// `{"at": {hikâye: ms}, "done": [hikâye, ...]}`. İsteğe bağlı `"path":
  /// {hikâye: [seçim sırası, ...]}` başlangıçtan kayıtlı düğüme seçilen yolu
  /// tutar (2026-10-25; eski kayıtlarda yoktur). Düğüm anahtarlarının
  /// (`zankurd.story.<id>`) önek taramasına karışmasın diye ayrı adlı.
  static String get metaKey =>
      LocalProgressScope.physical('zankurd.storyMeta.v1');
  static StoryProgressStore? _instance;
  static Future<StoryProgressStore>? _loading;
  static int _loadGeneration = 0;

  final SharedPreferences? _preferences;
  final Map<String, String> _nodes;
  final Map<String, int> _at;
  final Set<String> _done;
  final Map<String, List<int>> _paths;

  static Future<StoryProgressStore> load() async {
    final cached = _instance;
    if (cached != null) return cached;
    final inFlight = _loading;
    if (inFlight != null) return inFlight;

    final generation = _loadGeneration;
    final loading = _loadFresh().then((store) {
      if (_loadGeneration == generation) {
        return _instance ??= store;
      }
      return store;
    });
    _loading = loading;
    try {
      return await loading;
    } finally {
      if (identical(_loading, loading)) _loading = null;
    }
  }

  static Future<StoryProgressStore> _loadFresh() async {
    SharedPreferences? preferences;
    try {
      preferences = await SharedPreferences.getInstance();
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'story_progress_store');
      preferences = null;
    }
    final map = <String, String>{};
    if (preferences != null) {
      for (final key in preferences.getKeys()) {
        if (key.startsWith(_prefix)) {
          final v = preferences.getString(key);
          if (v != null) map[key.substring(_prefix.length)] = v;
        }
      }
    }
    final at = <String, int>{};
    final done = <String>{};
    final paths = <String, List<int>>{};
    final rawMeta = preferences?.getString(metaKey);
    if (rawMeta != null) {
      try {
        final decoded = jsonDecode(rawMeta);
        if (decoded is Map) {
          final rawAt = decoded['at'];
          if (rawAt is Map) {
            rawAt.forEach((k, v) {
              if (k is String && v is num) at[k] = v.toInt();
            });
          }
          final rawDone = decoded['done'];
          if (rawDone is List) {
            done.addAll(rawDone.whereType<String>());
          }
          final rawPath = decoded['path'];
          if (rawPath is Map) {
            rawPath.forEach((k, v) {
              if (k is String && v is List && v.every((i) => i is int)) {
                paths[k] = v.cast<int>();
              }
            });
          }
        }
      } catch (error, stack) {
        ErrorReporter.record(error, stack, reason: 'story_progress_meta');
      }
    }
    return StoryProgressStore._(preferences, map, at, done, paths);
  }

  static void resetInstance() {
    _loadGeneration++;
    _instance = null;
    _loading = null;
  }

  /// Kayıtlı düğüm id'si; hiç başlanmadıysa null.
  String? currentNodeId(String storyId) => _nodes[storyId];

  /// Başlangıçtan kayıtlı düğüme seçilen yol (her adımda seçimin sırası);
  /// bilinmiyorsa (eski kayıt, başka cihazdan eşitleme) null.
  List<int>? path(String storyId) => _paths[storyId];

  /// Hikâye bir kez sonuna ulaştı mı. "Yeniden oyna" bunu silmez.
  bool isCompleted(String storyId) => _done.contains(storyId);

  /// Kayıt en son ne zaman yazıldı (ms); eski kayıtlarda null.
  int? updatedAt(String storyId) => _at[storyId];

  Future<void> _writeMeta() async {
    await _preferences?.setString(
      metaKey,
      jsonEncode({
        'at': _at,
        'done': _done.toList()..sort(),
        if (_paths.isNotEmpty) 'path': _paths,
      }),
    );
    ProgressSyncService.markDirty();
  }

  /// [path] verilmezse o hikâyenin yolu bilinmez sayılır (silinir).
  Future<void> saveNode(
    String storyId,
    String nodeId, {
    List<int>? path,
  }) async {
    _nodes[storyId] = nodeId;
    if (path == null) {
      _paths.remove(storyId);
    } else {
      _paths[storyId] = List.unmodifiable(path);
    }
    _at[storyId] = DateTime.now().millisecondsSinceEpoch;
    await _preferences?.setString('$_prefix$storyId', nodeId);
    await _writeMeta();
  }

  /// Hikâyenin sonuna ulaşıldığını kalıcı işaretler (katalogdaki ✓).
  Future<void> markCompleted(String storyId) async {
    if (!_done.add(storyId)) return;
    await _writeMeta();
  }

  /// Hikâyeyi yeniden başlatır: ilerleme [startNodeId]'ye döner.
  ///
  /// Anahtar SİLİNMEZ; başlangıç düğümü yeni zaman damgasıyla yazılır.
  /// Silinseydi hesap eşitlemesi uzaktaki eski ilerlemeyi geri getirirdi
  /// (silinmiş kayıt ile hiç yazılmamış kayıt ayırt edilemez). "Bitirildi"
  /// işareti korunur.
  Future<void> restart(String storyId, String startNodeId) =>
      saveNode(storyId, startNodeId, path: const []);

  /// Hesap değişiminde önceki kullanıcının hikâye ilerlemesini cihazda bırakmaz.
  Future<void> clear() async {
    final storyIds = _nodes.keys.toList(growable: false);
    await removePersistedPreferenceKeys(
      _preferences,
      storyIds.map((storyId) => '$_prefix$storyId'),
    );
    _nodes.clear();
    await removePersistedPreferenceKeys(_preferences, [metaKey]);
    _at.clear();
    _done.clear();
    _paths.clear();
  }
}
