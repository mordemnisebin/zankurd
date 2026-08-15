import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/daily_mission.dart';
import '../utils/error_reporter.dart';

class DailyMissionStore {
  DailyMissionStore._(this._prefs, this._missions, this._correctAnswersToday);

  static const _dateKey = 'zankurd.missions.date';
  static const _progressKey = 'zankurd.missions.progress';
  static const _completedKey = 'zankurd.missions.completed';

  /// Bugün verilen doğru cevap sayısı — günlük göreve BAĞLI DEĞİL.
  ///
  /// ## Kusur
  ///
  /// Ana ekranın birincil kartı ("Erkê Îro / Dersê rojane") ilerlemesini
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
  static const _answeredKey = 'zankurd.missions.answeredToday';

  static DailyMissionStore? _instance;

  final SharedPreferences? _prefs;
  final List<DailyMission> _missions;
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

  static Future<DailyMissionStore> load() async {
    final cached = _instance;
    if (cached != null) return cached;

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

    final today = DateTime.now();
    final todayKey = _dateString(today);
    final storedDate = prefs?.getString(_dateKey);
    final missions = MissionDefinitions.forDay(today);
    var answeredToday = 0;

    if (storedDate == todayKey) {
      final progressList = prefs?.getStringList(_progressKey) ?? [];
      final completedList = prefs?.getStringList(_completedKey) ?? [];
      for (var i = 0; i < missions.length; i++) {
        if (i < progressList.length) {
          missions[i].progress = int.tryParse(progressList[i]) ?? 0;
        }
        if (i < completedList.length) {
          missions[i].completed = completedList[i] == 'true';
        }
      }
      // Tarih anahtarı görevlerle ORTAK: gün dönünce ikisi birlikte
      // sıfırlanır ve sayaç dünün doğrularını bugüne taşıyamaz.
      answeredToday = prefs?.getInt(_answeredKey) ?? 0;
    }

    return _instance = DailyMissionStore._(prefs, missions, answeredToday);
  }

  @visibleForTesting
  static Future<DailyMissionStore> loadForTest(
    List<DailyMission> missions,
  ) async {
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
    return _instance = DailyMissionStore._(prefs, missions, 0);
  }

  static void resetInstance() => _instance = null;

  Future<void> clear() async {
    for (final mission in _missions) {
      mission.progress = 0;
      mission.completed = false;
    }
    _correctAnswersToday = 0;
    await _prefs?.remove(_dateKey);
    await _prefs?.remove(_progressKey);
    await _prefs?.remove(_completedKey);
    await _prefs?.remove(_answeredKey);
  }

  Future<List<DailyMission>> reportQuizCompleted({
    required int correctAnswers,
    required String category,
    required bool streakAlive,
  }) async {
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
          mission.progress = (mission.progress + 1).clamp(0, mission.target);
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
    await _persist();
    return completed;
  }

  Future<DailyMission?> reportWildcardUsed() async {
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

  Future<void> _persist() async {
    final today = _dateString(DateTime.now());
    await _prefs?.setString(_dateKey, today);
    await _prefs?.setStringList(
      _progressKey,
      _missions.map((m) => m.progress.toString()).toList(),
    );
    await _prefs?.setStringList(
      _completedKey,
      _missions.map((m) => m.completed.toString()).toList(),
    );
    await _prefs?.setInt(_answeredKey, _correctAnswersToday);
  }
}
