import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'checked_preferences_removal.dart';
import 'local_progress_scope.dart';
import 'result_progress_journal.dart';

import '../models/daily_mission.dart';
import '../utils/error_reporter.dart';

class DailyMissionStore {
  DailyMissionStore._(
    this._prefs,
    this._missions,
    this._correctAnswersToday,
    this._loadedDateKey,
  );

  static String get _dateKey =>
      LocalProgressScope.physical('zankurd.missions.date');
  static String get _progressKey =>
      LocalProgressScope.physical('zankurd.missions.progress');
  static String get _completedKey =>
      LocalProgressScope.physical('zankurd.missions.completed');
  static String get _claimedKey =>
      LocalProgressScope.physical('zankurd.missions.claimed');

  /// Bugün verilen doğru cevap sayısı — günlük göreve BAĞLI DEĞİL.
  ///
  /// ## Kusur
  ///
  /// Ana ekranın birincil kartı ("Erkê Îro / Dersa rojê") ilerlemesini
  /// `MissionType.answerCorrect` görevinden ödünç alıyordu. Ama günün üç
  /// görevi on altı tanelik havuzdan gün tohumuyla çekiliyor ve havuzda o
  /// türden yalnız üç tanım var; çoğu gün seçilmiyor. O günlerde kart
  /// sabah açılıyor, oyuncu on soru doğru cevaplıyor, XP artıyor, zincir
  /// uzuyor — kart hâlâ 0/10 yazıyor. Uygulamanın en görünür ilerleme
  /// göstergesi gün boyu kıpırdamıyordu (2026-08-12 simülatör turu).
  ///
  /// Sessizdi çünkü bir görev seçildiği günlerde her şey çalışıyordu;
  /// kusur takvime bağlıydı ve testler sabit görev listesiyle koşuyordu.
  ///
  /// Sayaç buraya konuyor çünkü "bugün" kavramının sahibi bu depo: tarih
  /// anahtarı, sıfırlama ve kalıcılık zaten burada.
  static String get _answeredKey =>
      LocalProgressScope.physical('zankurd.missions.answeredToday');

  static DailyMissionStore? _instance;
  static Future<DailyMissionStore>? _loading;
  static String? _loadingDateKey;
  static int _loadGeneration = 0;

  final String _physicalPrefix = LocalProgressScope.physical(
    'zankurd.missions',
  );
  String get _journalNamespace => '$_physicalPrefix.resultJournal';

  final SharedPreferences? _prefs;
  final List<DailyMission> _missions;
  final String _loadedDateKey;
  int _correctAnswersToday;

  List<DailyMission> get missions => List.unmodifiable(_missions);

  /// Bugün verilen doğru cevap sayısı. Gün dönünce sıfırlanır.
  int get correctAnswersToday => _correctAnswersToday;

  static bool _isSameCategory(String c1, String? c2) {
    if (c2 == null) return false;
    return c1 == c2 || c1.trim().toLowerCase() == c2.trim().toLowerCase();
  }

  static String _dateString(DateTime day) =>
      '${day.year}-${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}';

  static Future<DailyMissionStore> load({DateTime? now}) async {
    final today = now ?? DateTime.now();
    final todayKey = _dateString(today);
    final cached = _instance;
    if (cached != null && cached._loadedDateKey == todayKey) return cached;

    if (_loadingDateKey == todayKey) {
      final inFlight = _loading;
      if (inFlight != null) return inFlight;
    }

    final generation = _loadGeneration;
    _loadingDateKey = todayKey;
    final loading = _loadFresh(today, todayKey).then((store) {
      if (_loadGeneration == generation) {
        return _instance = store;
      }
      return store;
    });
    _loading = loading;
    try {
      return await loading;
    } finally {
      if (identical(_loading, loading)) {
        _loading = null;
        _loadingDateKey = null;
      }
    }
  }

  static Future<DailyMissionStore> _loadFresh(
    DateTime today,
    String todayKey,
  ) async {
    SharedPreferences? prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } catch (error, stack) {
      ErrorReporter.record(
        error,
        stack,
        reason: 'daily_mission_load_preferences',
      );
    }

    if (prefs != null) {
      await ResultProgressJournal.recover(
        preferences: prefs,
        namespace: LocalProgressScope.physical(
          'zankurd.missions.resultJournal',
        ),
      );
    }
    final storedDate = prefs?.getString(_dateKey);
    final missions = MissionDefinitions.forDay(today);
    var answeredToday = 0;

    if (storedDate == todayKey) {
      final progressList = prefs?.getStringList(_progressKey) ?? [];
      final completedList = prefs?.getStringList(_completedKey) ?? [];
      final claimedList = prefs?.getStringList(_claimedKey) ?? [];
      for (var i = 0; i < missions.length; i++) {
        if (i < progressList.length) {
          missions[i].progress = int.tryParse(progressList[i]) ?? 0;
        }
        if (i < completedList.length) {
          missions[i].completed = completedList[i] == 'true';
        }
        if (i < claimedList.length) {
          missions[i].claimed = claimedList[i] == 'true';
        }
      }
      // Tarih anahtarı görevlerle ORTAK: gün dönünce ikisi birlikte
      // sıfırlanır ve sayaç dünün doğrularını bugüne taşıyamaz.
      answeredToday = prefs?.getInt(_answeredKey) ?? 0;
    }

    return DailyMissionStore._(prefs, missions, answeredToday, todayKey);
  }

  @visibleForTesting
  static Future<DailyMissionStore> loadForTest(
    List<DailyMission> missions,
  ) async {
    _loadGeneration++;
    _loading = null;
    _loadingDateKey = null;
    SharedPreferences? prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } catch (error, stack) {
      ErrorReporter.record(
        error,
        stack,
        reason: 'daily_mission_test_preferences',
      );
    }
    return _instance = DailyMissionStore._(
      prefs,
      missions,
      0,
      _dateString(DateTime.now()),
    );
  }

  static void resetInstance() {
    _loadGeneration++;
    _instance = null;
    _loading = null;
    _loadingDateKey = null;
  }

  Future<void> clear() async {
    await removePersistedPreferenceKeys(_prefs, [
      ..._progressValues().keys,
      ...?_prefs?.getKeys().where(
        (key) => key.startsWith('$_journalNamespace.'),
      ),
    ]);
    for (final mission in _missions) {
      mission.progress = 0;
      mission.completed = false;
      mission.claimed = false;
    }
    _correctAnswersToday = 0;
  }

  Future<List<DailyMission>> reportQuizCompleted({
    required int correctAnswers,
    required String category,
    required bool streakAlive,
    bool countsAsRace = true,
    String? completionId,
  }) async {
    final prefs = _prefs;
    if (completionId != null) {
      if (prefs == null) throw StateError('Mission preferences unavailable');
      final result = await ResultProgressJournal.run(
        preferences: prefs,
        namespace: _journalNamespace,
        operationId: completionId,
        prepare: () {
          _reloadProgress();
          // Journal hazırlığı belleği değiştirmez: yazım reddedilirse aynı
          // tur güvenle yeniden denenir; yalnız kalıcı hedefler artar.
          final draft = DailyMissionStore._(
            null,
            [
              for (final m in _missions)
                DailyMission(
                  type: m.type,
                  target: m.target,
                  coinReward: m.coinReward,
                  category: m.category,
                  progress: m.progress,
                  completed: m.completed,
                  claimed: m.claimed,
                ),
            ],
            _correctAnswersToday,
            _loadedDateKey,
          );
          final completed = draft._applyQuizCompleted(
            correctAnswers: correctAnswers,
            category: category,
            streakAlive: streakAlive,
            countsAsRace: countsAsRace,
          );
          return ResultProgressMutation(
            values: _progressValues(
              missions: draft._missions,
              correctAnswers: draft._correctAnswersToday,
            ),
            result: {
              'completedIds': completed.map((m) => m.missionKey).toList(),
              'date': _loadedDateKey,
            },
          );
        },
      );
      _reloadProgress();
      if (result['date'] != _loadedDateKey) return [];
      final completedIds = (result['completedIds'] as List).cast<String>();
      return _missions
          .where((m) => completedIds.contains(m.missionKey))
          .toList();
    }
    if (prefs != null) {
      await ResultProgressJournal.recover(
        preferences: prefs,
        namespace: _journalNamespace,
      );
      _reloadProgress();
    }
    final completed = _applyQuizCompleted(
      correctAnswers: correctAnswers,
      category: category,
      streakAlive: streakAlive,
      countsAsRace: countsAsRace,
    );
    await _persist();
    return completed;
  }

  List<DailyMission> _applyQuizCompleted({
    required int correctAnswers,
    required String category,
    required bool streakAlive,
    required bool countsAsRace,
  }) {
    final completed = <DailyMission>[];
    // Görev listesinden ÖNCE ve ondan bağımsız: bugünün doğruları o gün
    // hangi görevlerin çekildiğine bakmaksızın sayılır.
    if (correctAnswers > 0) _correctAnswersToday += correctAnswers;
    for (final mission in _missions) {
      if (mission.completed) continue;
      switch (mission.type) {
        case MissionType.answerCorrect:
          mission.progress = (mission.progress + correctAnswers).clamp(
            0,
            mission.target,
          );
        case MissionType.completeQuiz:
          // "Yarış tamamla": yalnız yarış turları (düello, oda, bot yarışı,
          // günün turu) sayılır. Tek başına çözülen "Pratik" turu yarış
          // değildir ve görevi tamamlamamalı (2026-10-29, X5).
          if (countsAsRace) {
            mission.progress = (mission.progress + 1).clamp(0, mission.target);
          }
        case MissionType.keepStreak:
          if (streakAlive) mission.progress = mission.target;
        case MissionType.playCategory:
          if (_isSameCategory(category, mission.category)) {
            mission.progress = mission.target;
          }
        case MissionType.useWildcard:
          break;
      }
      if (!mission.completed && mission.progress >= mission.target) {
        mission.completed = true;
        completed.add(mission);
      }
    }
    return completed;
  }

  Future<DailyMission?> reportWildcardUsed() async {
    await _recoverPending();
    for (final mission in _missions) {
      if (mission.completed || mission.type != MissionType.useWildcard) {
        continue;
      }
      mission.progress = (mission.progress + 1).clamp(0, mission.target);
      if (mission.progress >= mission.target) mission.completed = true;
      await _persist();
      return mission.completed ? mission : null;
    }
    return null;
  }

  static final Set<String> _claimsInFlight = <String>{};

  /// Ödülü [grant] BAŞARILI olduktan sonra "alındı" diye kalıcı yazar.
  ///
  /// Bayrak ödülden önce yazılınca `addXP` düşerse görev "alındı" kalıyor,
  /// XP hiç gelmiyordu. Burada [grant] fırlatırsa bayrak yazılmaz ve `false`
  /// döner (kullanıcı yeniden deneyebilir). Aynı görev için eşzamanlı ikinci
  /// çağrı `false` döner (çift XP yok).
  Future<bool> claimRewardAfter(
    DailyMission mission,
    Future<void> Function() grant,
  ) async {
    await _recoverPending();
    // Eşitleme `DailyMissionStore` örneğini yenilerken ekran eski görev
    // nesnesini tutabilir: alındı bayrağı eski nesnede değişir, `_persist`
    // yeni deponun hâlâ alınmamış görevini yazar ve aynı ödül yeniden
    // alınabilirdi. Karar GÜNCEL deponun kendi görevine göre verilir.
    final live = _missions
        .where(
          (m) =>
              m.type == mission.type &&
              m.category == mission.category &&
              m.target == mission.target,
        )
        .firstOrNull;
    if (live != null && !identical(live, mission)) {
      if (live.claimed) mission.claimed = true;
      mission = live;
    }
    if (!mission.completed || mission.claimed) return false;
    final flightKey =
        '${mission.type.name}|${mission.category}|'
        '${mission.target}|$_loadedDateKey';
    if (!_claimsInFlight.add(flightKey)) return false;
    try {
      try {
        await grant();
      } catch (error, stack) {
        ErrorReporter.record(error, stack, reason: 'mission_claim_grant');
        return false;
      }
      mission.claimed = true;
      await _persist();
      return true;
    } finally {
      _claimsInFlight.remove(flightKey);
    }
  }

  Future<bool> claimReward(DailyMission mission) async {
    await _recoverPending();
    if (!mission.completed || mission.claimed) return false;
    mission.claimed = true;
    await _persist();
    return true;
  }

  Future<void> _recoverPending() async {
    final prefs = _prefs;
    if (prefs == null) return;
    await ResultProgressJournal.recover(
      preferences: prefs,
      namespace: _journalNamespace,
    );
    _reloadProgress();
  }

  Map<String, Object> _progressValues({
    List<DailyMission>? missions,
    int? correctAnswers,
  }) {
    final current = missions ?? _missions;
    return {
      '$_physicalPrefix.date': _loadedDateKey,
      '$_physicalPrefix.progress': current
          .map((m) => m.progress.toString())
          .toList(),
      '$_physicalPrefix.completed': current
          .map((m) => m.completed.toString())
          .toList(),
      '$_physicalPrefix.claimed': current
          .map((m) => m.claimed.toString())
          .toList(),
      '$_physicalPrefix.answeredToday': correctAnswers ?? _correctAnswersToday,
    };
  }

  void _reloadProgress() {
    final prefs = _prefs;
    if (prefs == null ||
        prefs.getString('$_physicalPrefix.date') != _loadedDateKey) {
      return;
    }
    final progress = prefs.getStringList('$_physicalPrefix.progress') ?? [];
    final completed = prefs.getStringList('$_physicalPrefix.completed') ?? [];
    final claimed = prefs.getStringList('$_physicalPrefix.claimed') ?? [];
    for (var i = 0; i < _missions.length; i++) {
      if (i < progress.length) {
        _missions[i].progress = int.tryParse(progress[i]) ?? 0;
      }
      if (i < completed.length) _missions[i].completed = completed[i] == 'true';
      if (i < claimed.length) _missions[i].claimed = claimed[i] == 'true';
    }
    _correctAnswersToday = prefs.getInt('$_physicalPrefix.answeredToday') ?? 0;
  }

  Future<void> _persist() async {
    final prefs = _prefs;
    if (prefs == null) return;
    for (final entry in _progressValues().entries) {
      final value = entry.value;
      if (value is String) {
        await prefs.setString(entry.key, value);
      } else if (value is int) {
        await prefs.setInt(entry.key, value);
      } else {
        await prefs.setStringList(entry.key, value as List<String>);
      }
    }
  }
}
