import 'package:shared_preferences/shared_preferences.dart';

import '../models/learning_goal.dart';
import '../utils/error_reporter.dart';

/// İlk 5 dakikanın (tanıtım -> amaç -> seviye -> ilk ders) kalıcı durumu.
///
/// Sürekli akış tek bir ekranda yaşamaz: tanıtım ile ilk ders arasında giriş
/// (misafir/Apple/Google) ve ad kapısı durur, uygulama bu aralıkta kapanabilir.
/// Bu yüzden akışın nerede kaldığı CİHAZA bağlı iki aşamalı bir işaretle
/// saklanır (kullanıcıya bağlı değil: akış hesap açılmadan başlar).
///
///  * [FirstRunStage.choice]: tanıtım bitti, amaç/seviye soruları bekliyor.
///  * [FirstRunStage.launch]: cevaplar alındı, kabuk açılınca ilk derse inilecek.
///
/// İşaret YALNIZ yeni tanıtım bittiğinde konur; tanıtımı çoktan görmüş
/// (mevcut) kullanıcıda hiç yoktur, akış ona asla gösterilmez. Tüketilen
/// işaret hemen silinir: ders yarıda kalsa da akış ikinci kez açılmaz.
enum FirstRunStage { choice, launch }

class FirstRunPlan {
  const FirstRunPlan({this.goal, this.wantsPlacement = false});

  final LearningGoal? goal;

  /// "Biraz biliyorum" dendi: önce seviye belirleme sınavı.
  final bool wantsPlacement;
}

class FirstRunStore {
  const FirstRunStore._();

  static const stageKey = 'zankurd.firstRun.v1.stage';
  static const goalKey = 'zankurd.firstRun.v1.goal';
  static const placementKey = 'zankurd.firstRun.v1.placement';

  static Future<FirstRunStage?> stage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return switch (prefs.getString(stageKey)) {
        'choice' => FirstRunStage.choice,
        'launch' => FirstRunStage.launch,
        _ => null,
      };
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'first_run_stage');
      return null;
    }
  }

  /// Tanıtım bitti: sorular sırada.
  static Future<void> armChoice() => _write(FirstRunStage.choice);

  /// Cevaplar alındı (atlandıysa varsayılan: amaçsız, baştan).
  static Future<void> saveChoice(FirstRunPlan plan) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final goal = plan.goal;
      if (goal == null) {
        await prefs.remove(goalKey);
      } else {
        await prefs.setString(goalKey, goal.storageKey);
      }
      await prefs.setBool(placementKey, plan.wantsPlacement);
      await prefs.setString(stageKey, 'launch');
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'first_run_save');
    }
  }

  /// İlk derse inme sırası geldiyse planı verir ve işareti SİLER.
  static Future<FirstRunPlan?> consumeLaunch() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getString(stageKey) != 'launch') return null;
      final plan = FirstRunPlan(
        goal: LearningGoal.fromStorageKey(prefs.getString(goalKey)),
        wantsPlacement: prefs.getBool(placementKey) ?? false,
      );
      await prefs.remove(stageKey);
      await prefs.remove(goalKey);
      await prefs.remove(placementKey);
      return plan;
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'first_run_consume');
      return null;
    }
  }

  static Future<void> _write(FirstRunStage stage) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(stageKey, stage.name);
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'first_run_arm');
    }
  }
}
