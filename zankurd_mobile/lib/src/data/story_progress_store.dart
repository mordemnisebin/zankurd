import 'package:shared_preferences/shared_preferences.dart';

import '../utils/error_reporter.dart';

/// Hikâye ilerlemesini (mevcut düğüm id'si) yerelde tutar; devam etme ve
/// yeniden başlatmayı destekler. `SharedPreferences` yoksa bellek-içi çalışır.
class StoryProgressStore {
  StoryProgressStore._(this._preferences, this._nodes);

  static const _prefix = 'zankurd.story.';
  static StoryProgressStore? _instance;

  final SharedPreferences? _preferences;
  final Map<String, String> _nodes;

  static Future<StoryProgressStore> load() async {
    final cached = _instance;
    if (cached != null) return cached;
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
    return _instance = StoryProgressStore._(preferences, map);
  }

  static void resetInstance() => _instance = null;

  /// Kayıtlı düğüm id'si; hiç başlanmadıysa null.
  String? currentNodeId(String storyId) => _nodes[storyId];

  Future<void> saveNode(String storyId, String nodeId) async {
    _nodes[storyId] = nodeId;
    await _preferences?.setString('$_prefix$storyId', nodeId);
  }

  /// Hikâyeyi yeniden başlatır (ilerlemeyi siler).
  Future<void> restart(String storyId) async {
    _nodes.remove(storyId);
    await _preferences?.remove('$_prefix$storyId');
  }
}
