import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart'
    show AppLifecycleState, WidgetsBinding, WidgetsBindingObserver;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/placement_scoring.dart';
import '../utils/error_reporter.dart';
import 'local_progress_scope.dart';
import 'progress_snapshot.dart';

/// Yerel SharedPreferences <-> [ProgressSnapshot] dönüşümü.
///
/// Anahtarlar mağazaların kendi (kullanıcıya kapsamlı) anahtarlarıdır
/// ([LocalProgressScope.physical]); mağaza sınıflarına dokunulmaz. Okuma ve
/// yazma AKTİF kapsam üzerindedir: kapsam bu kullanıcıya bağlı değilse
/// çağıran eşitlemeyi başlatmamalıdır ([ProgressSyncService] bunu denetler).
class LocalProgressSnapshot {
  const LocalProgressSnapshot._();

  static const _xp = 'zankurd.xp.total';
  static const _streakCurrent = 'zankurd.streak.current';
  static const _streakBest = 'zankurd.streak.best';
  static const _streakLastDay = 'zankurd.streak.lastDay';
  static const _streakFreeze = 'zankurd.streak.freeze';
  static const _badges = 'zankurd.badges.unlocked';
  static const _achUnlocked = 'zankurd.achievements.unlocked';
  static const _achAnswered = 'zankurd.achievements.answeredQuestions';
  static const _achCategories = 'zankurd.achievements.playedCategories';
  static const _achDailyQuiz = 'zankurd.achievements.dailyQuizCompletions';
  static const _achDailyQuizDay = 'zankurd.achievements.dailyQuizLastDay';
  static const _levelPlayed = 'zankurd.level.played';
  static const _masteryPrefix = 'zankurd.mastery.';
  static const _masteryAnsweredPrefix = 'zankurd.masteryAnswered.';
  static const _masteryEvidencePrefix = 'zankurd.masteryEvidenceCorrect.';
  static const _mistakeIds = 'zankurd.mistakeQuestionIds';
  static const _mistakeMeta = 'zankurd.mistakeMetadata';
  static const _mistakeHistory = 'zankurd.dailyPerformance';
  static const _placementLevel = 'zankurd.placement.v1.level';
  static const _placementSkipped = 'zankurd.placement.v1.skipped';
  static const _storyPrefix = 'zankurd.story.';
  static const _goal = 'zankurd.learning_goal.v1';

  static String _k(String logical) => LocalProgressScope.physical(logical);

  /// Yerel durumu okur.
  static ProgressSnapshot read(SharedPreferences prefs) {
    final mastery = <String, SnapshotMastery>{};
    final masteryP = _k(_masteryPrefix);
    final answeredP = _k(_masteryAnsweredPrefix);
    final evidenceP = _k(_masteryEvidencePrefix);
    final categories = <String>{};
    for (final key in prefs.getKeys()) {
      if (key.startsWith(masteryP)) {
        categories.add(key.substring(masteryP.length));
      } else if (key.startsWith(answeredP)) {
        categories.add(key.substring(answeredP.length));
      } else if (key.startsWith(evidenceP)) {
        categories.add(key.substring(evidenceP.length));
      }
    }
    for (final category in categories) {
      mastery[category] = SnapshotMastery(
        correct: prefs.getInt('$masteryP$category') ?? 0,
        answered: prefs.getInt('$answeredP$category') ?? 0,
        evidence: prefs.getInt('$evidenceP$category') ?? 0,
      );
    }

    final story = <String, String>{};
    final storyP = _k(_storyPrefix);
    for (final key in prefs.getKeys()) {
      if (key.startsWith(storyP)) {
        final node = prefs.getString(key);
        if (node != null) story[key.substring(storyP.length)] = node;
      }
    }

    final placement = prefs.getString(_k(_placementLevel));
    return ProgressSnapshot(
      xp: prefs.getInt(_k(_xp)) ?? 0,
      streak: SnapshotStreak(
        current: prefs.getInt(_k(_streakCurrent)) ?? 0,
        best: prefs.getInt(_k(_streakBest)) ?? 0,
        lastDay: prefs.getString(_k(_streakLastDay)),
        freeze: prefs.getInt(_k(_streakFreeze)) ?? 0,
      ),
      badges: (prefs.getStringList(_k(_badges)) ?? const []).toSet(),
      achievements: SnapshotAchievements(
        unlocked: (prefs.getStringList(_k(_achUnlocked)) ?? const []).toSet(),
        answered: prefs.getInt(_k(_achAnswered)) ?? 0,
        categories: (prefs.getStringList(_k(_achCategories)) ?? const [])
            .toSet(),
        dailyQuiz: prefs.getInt(_k(_achDailyQuiz)) ?? 0,
        dailyQuizDay: prefs.getString(_k(_achDailyQuizDay)),
      ),
      levelPlayed: (prefs.getStringList(_k(_levelPlayed)) ?? const []).toSet(),
      mastery: mastery,
      mistakes: SnapshotMistakes(
        ids: (prefs.getStringList(_k(_mistakeIds)) ?? const []).toSet(),
        meta: _decodeMeta(prefs.getString(_k(_mistakeMeta))),
        history: _decodeHistory(prefs.getString(_k(_mistakeHistory))),
      ),
      placementLevel: PlacementLevel.fromStorageKey(placement)?.storageKey,
      placementSkipped: prefs.getBool(_k(_placementSkipped)) ?? false,
      story: story,
      learningGoal: prefs.getString(_k(_goal)),
    );
  }

  /// [snapshot]'u yerel anahtarlara yazar. Hepsi başarılıysa `true`.
  ///
  /// Yalnız birleştirmede DEĞİŞEN değerler yazılır; çağıran, yazımdan sonra
  /// bellekteki mağaza örneklerini sıfırlamalıdır.
  static Future<bool> write(
    SharedPreferences prefs,
    ProgressSnapshot snapshot,
  ) async {
    final current = read(prefs);
    var ok = true;

    Future<void> setInt(String logical, int value) async {
      if ((prefs.getInt(_k(logical)) ?? 0) == value) return;
      ok = await prefs.setInt(_k(logical), value) && ok;
    }

    Future<void> setList(String logical, Set<String> value) async {
      final existing = (prefs.getStringList(_k(logical)) ?? const []).toSet();
      if (existing.length == value.length && existing.containsAll(value)) {
        return;
      }
      ok = await prefs.setStringList(_k(logical), value.toList()..sort()) && ok;
    }

    Future<void> setString(String logical, String? value) async {
      if (value == null || prefs.getString(_k(logical)) == value) return;
      ok = await prefs.setString(_k(logical), value) && ok;
    }

    await setInt(_xp, snapshot.xp);
    await setInt(_streakCurrent, snapshot.streak.current);
    await setInt(_streakBest, snapshot.streak.best);
    await setInt(_streakFreeze, snapshot.streak.freeze);
    await setString(_streakLastDay, snapshot.streak.lastDay);
    await setList(_badges, snapshot.badges);
    await setList(_achUnlocked, snapshot.achievements.unlocked);
    await setInt(_achAnswered, snapshot.achievements.answered);
    await setList(_achCategories, snapshot.achievements.categories);
    await setInt(_achDailyQuiz, snapshot.achievements.dailyQuiz);
    await setString(_achDailyQuizDay, snapshot.achievements.dailyQuizDay);
    await setList(_levelPlayed, snapshot.levelPlayed);

    for (final entry in snapshot.mastery.entries) {
      final before = current.mastery[entry.key] ?? const SnapshotMastery();
      final value = entry.value;
      if (before.correct != value.correct) {
        ok =
            await prefs.setInt(
              '${_k(_masteryPrefix)}${entry.key}',
              value.correct,
            ) &&
            ok;
      }
      if (before.answered != value.answered) {
        ok =
            await prefs.setInt(
              '${_k(_masteryAnsweredPrefix)}${entry.key}',
              value.answered,
            ) &&
            ok;
      }
      if (before.evidence != value.evidence) {
        ok =
            await prefs.setInt(
              '${_k(_masteryEvidencePrefix)}${entry.key}',
              value.evidence,
            ) &&
            ok;
      }
    }

    await setList(_mistakeIds, snapshot.mistakes.ids);
    if (!_sameJson(current.mistakes.meta, snapshot.mistakes.meta)) {
      ok =
          await prefs.setString(
            _k(_mistakeMeta),
            jsonEncode(snapshot.mistakes.meta),
          ) &&
          ok;
    }
    if (!_sameJson(current.mistakes.history, snapshot.mistakes.history)) {
      ok =
          await prefs.setString(
            _k(_mistakeHistory),
            jsonEncode(snapshot.mistakes.history),
          ) &&
          ok;
    }

    if (snapshot.placementLevel != null &&
        snapshot.placementLevel != current.placementLevel) {
      ok =
          await prefs.setString(
            _k(_placementLevel),
            snapshot.placementLevel!,
          ) &&
          ok;
      if (prefs.containsKey(_k(_placementSkipped))) {
        ok = await prefs.remove(_k(_placementSkipped)) && ok;
      }
    } else if (snapshot.placementLevel == null &&
        snapshot.placementSkipped &&
        !current.placementSkipped) {
      ok = await prefs.setBool(_k(_placementSkipped), true) && ok;
    }

    for (final entry in snapshot.story.entries) {
      if (current.story[entry.key] == entry.value) continue;
      ok =
          await prefs.setString(
            '${_k(_storyPrefix)}${entry.key}',
            entry.value,
          ) &&
          ok;
    }
    await setString(_goal, snapshot.learningGoal);
    return ok;
  }

  static bool _sameJson(Object? a, Object? b) => jsonEncode(a) == jsonEncode(b);

  static Map<String, Map<String, dynamic>> _decodeMeta(String? raw) {
    if (raw == null) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      return {
        for (final entry in decoded.entries)
          if (entry.key is String && entry.value is Map)
            entry.key as String: Map<String, dynamic>.from(entry.value as Map),
      };
    } catch (_) {
      return {};
    }
  }

  static Map<String, Map<String, int>> _decodeHistory(String? raw) {
    if (raw == null) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      return {
        for (final entry in decoded.entries)
          if (entry.key is String && entry.value is Map)
            entry.key as String: {
              'correct':
                  ((entry.value as Map)['correct'] as num?)?.toInt() ?? 0,
              'wrong': ((entry.value as Map)['wrong'] as num?)?.toInt() ?? 0,
            },
      };
    } catch (_) {
      return {};
    }
  }
}

/// Sunucudaki anlık görüntü satırı.
class RemoteProgress {
  const RemoteProgress({required this.snapshot, this.updatedAt});

  final Map<String, dynamic> snapshot;
  final DateTime? updatedAt;
}

/// `get_my_progress` / `save_my_progress` RPC sözleşmesi, test için soyut.
abstract class ProgressRemote {
  /// Kayıtlı anlık görüntü; yoksa `null`.
  Future<RemoteProgress?> fetch();

  Future<void> save(Map<String, dynamic> snapshot);
}

/// RPC sunucuda yok (göç uygulanmamış): eşitleme oturum boyunca kapanır.
class ProgressRemoteMissing implements Exception {
  const ProgressRemoteMissing();
}

class SupabaseProgressRemote implements ProgressRemote {
  SupabaseProgressRemote(this._client);

  final SupabaseClient _client;

  static bool _isMissing(PostgrestException error) =>
      error.code == 'PGRST202' ||
      error.code == '42883' ||
      error.code == 'PGRST205';

  @override
  Future<RemoteProgress?> fetch() async {
    try {
      final response = await _client.rpc<dynamic>('get_my_progress');
      if (response is! Map) return null;
      final snapshot = response['snapshot'];
      if (snapshot is! Map) return null;
      return RemoteProgress(
        snapshot: Map<String, dynamic>.from(snapshot),
        updatedAt: DateTime.tryParse('${response['updated_at']}'),
      );
    } on PostgrestException catch (error) {
      if (_isMissing(error)) throw const ProgressRemoteMissing();
      rethrow;
    }
  }

  @override
  Future<void> save(Map<String, dynamic> snapshot) async {
    try {
      await _client.rpc<dynamic>(
        'save_my_progress',
        params: {'p_snapshot': snapshot},
      );
    } on PostgrestException catch (error) {
      if (_isMissing(error)) throw const ProgressRemoteMissing();
      rethrow;
    }
  }
}

/// Kayıtlı (misafir olmayan) kullanıcının ilerlemesini hesapla eşitler.
///
/// Akış ([syncNow]): sunucudaki anlık görüntüyü çek -> yerelle BİRLEŞTİR ->
/// yerel değiştiyse yaz -> sunucudan farklıysa geri yükle. Yükleme sonuç
/// kaydından sonra seyreltilmiş (debounce) ve uygulama arka plana geçince
/// hemen yapılır; oturum açılışında ve çıkıştan önce de çalışır.
///
/// Sunucu yoksa (göç uygulanmamış, `PGRST202`) ya da ağ yoksa sessizce yerel
/// davranış sürer: hiçbir hata kullanıcıya taşınmaz.
class ProgressSyncService with WidgetsBindingObserver {
  ProgressSyncService({
    required this.remote,
    required this.userId,
    SharedPreferences? preferences,
    this.onLocalChanged,
    this.debounce = const Duration(seconds: 20),
    // ignore: prefer_initializing_formals
  }) : _preferences = preferences;

  static ProgressSyncService? _instance;
  static ProgressSyncService? get maybeInstance => _instance;

  final ProgressRemote remote;
  final String userId;
  final SharedPreferences? _preferences;

  /// Birleştirme yerel anahtarları değiştirdiğinde (bellekteki mağaza
  /// örneklerini sıfırlamak için).
  final void Function()? onLocalChanged;
  final Duration debounce;

  Timer? _timer;
  Future<void> _chain = Future<void>.value();
  bool _disabled = false;
  bool _closed = false;
  bool _observing = false;

  bool get isDisabled => _disabled;

  /// Oturum açıkken kurulur; bir öncekini kapatır. Yalnız kayıtlı kullanıcı
  /// ve kapsamı o kullanıcıya bağlıyken çağrılmalıdır.
  static ProgressSyncService bind({
    required ProgressRemote remote,
    required String userId,
    SharedPreferences? preferences,
    void Function()? onLocalChanged,
    Duration debounce = const Duration(seconds: 20),
  }) {
    final previous = _instance;
    if (previous != null && previous.userId == userId && !previous._closed) {
      return previous;
    }
    previous?.close();
    final service = ProgressSyncService(
      remote: remote,
      userId: userId,
      preferences: preferences,
      onLocalChanged: onLocalChanged,
      debounce: debounce,
    ).._observe();
    return _instance = service;
  }

  static void unbind() {
    _instance?.close();
    _instance = null;
  }

  /// Bir sonuç kaydedildi: kısa bir gecikmeyle yükle.
  static void markDirty() => _instance?.scheduleUpload();

  void _observe() {
    if (_observing) return;
    try {
      WidgetsBinding.instance.addObserver(this);
      _observing = true;
    } catch (_) {
      // Binding yok (saf Dart testi).
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      unawaited(syncNow());
    }
  }

  void scheduleUpload() {
    if (_closed || _disabled) return;
    _timer?.cancel();
    _timer = Timer(debounce, () => unawaited(syncNow()));
  }

  /// Çıkıştan önce: bekleyen eşitlemeyi [timeout] içinde bitirmeyi dener.
  Future<void> flush({Duration timeout = const Duration(seconds: 4)}) async {
    _timer?.cancel();
    _timer = null;
    try {
      await syncNow().timeout(timeout);
    } catch (_) {
      // Zaman aşımı ya da ağ: yerel ilerleme zaten cihazda duruyor.
    }
  }

  void close() {
    _closed = true;
    _timer?.cancel();
    _timer = null;
    if (_observing) {
      try {
        WidgetsBinding.instance.removeObserver(this);
      } catch (_) {}
      _observing = false;
    }
  }

  /// Çek -> birleştir -> yaz -> gerekirse yükle. Aynı anda tek koşu (sıra).
  Future<void> syncNow() {
    if (_closed || _disabled) return Future<void>.value();
    final run = _chain.then((_) => _syncOnce());
    _chain = run.catchError((Object _) {});
    return run;
  }

  Future<void> _syncOnce() async {
    if (_closed || _disabled) return;
    try {
      // Kapsam başka kullanıcıya geçtiyse (hızlı hesap değişimi) dokunma.
      if (LocalProgressScope.activeUserId != userId) return;
      final prefs = _preferences ?? await SharedPreferences.getInstance();
      final local = LocalProgressSnapshot.read(prefs);

      final row = await remote.fetch();
      if (_closed || LocalProgressScope.activeUserId != userId) return;

      ProgressSnapshot merged = local;
      ProgressSnapshot? remoteSnapshot;
      if (row != null) {
        remoteSnapshot = ProgressSnapshot.tryParse(row.snapshot);
        if (remoteSnapshot == null) {
          // Daha yeni sürüm ya da bozuk kayıt: üzerine yazma, birleştirme.
          return;
        }
        merged = ProgressSnapshot.merge(local, remoteSnapshot);
      }

      if (merged != local) {
        if (await LocalProgressSnapshot.write(prefs, merged)) {
          onLocalChanged?.call();
        } else {
          ErrorReporter.record(
            StateError('Merged progress was not persisted locally.'),
            StackTrace.current,
            reason: 'progress_sync_local_write',
          );
          return;
        }
      }

      if (merged.isEmpty) return;
      if (remoteSnapshot != null && merged == remoteSnapshot) return;
      final json = _compact(merged);
      if (json == null) return;
      await remote.save(json);
    } on ProgressRemoteMissing {
      _disabled = true;
    } catch (error, stack) {
      if (!_isNetwork(error)) {
        ErrorReporter.record(error, stack, reason: 'progress_sync');
      }
    }
  }

  /// 240 KB'ı aşarsa önce günlük performans geçmişini bırakır; yine de
  /// aşıyorsa yüklemeyi atlar (sunucu 256 KB'ta reddederdi).
  static Map<String, dynamic>? _compact(ProgressSnapshot snapshot) {
    var json = snapshot.toJson();
    if (jsonEncode(json).length <= ProgressSnapshot.maxEncodedBytes) {
      return json;
    }
    json = Map<String, dynamic>.from(json);
    final mistakes = Map<String, dynamic>.from(json['mistakes'] as Map);
    mistakes['history'] = <String, dynamic>{};
    json['mistakes'] = mistakes;
    if (jsonEncode(json).length <= ProgressSnapshot.maxEncodedBytes) {
      return json;
    }
    return null;
  }

  static bool _isNetwork(Object error) {
    final text = error.toString().toLowerCase();
    return error is TimeoutException ||
        text.contains('socket') ||
        text.contains('clientexception') ||
        text.contains('failed host lookup') ||
        text.contains('network') ||
        text.contains('connection') ||
        text.contains('xmlhttprequest');
  }
}
