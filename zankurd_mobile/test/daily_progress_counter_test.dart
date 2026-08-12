import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/daily_mission_store.dart';
import 'package:zankurd_mobile/src/models/daily_mission.dart';

/// "Bugün kaç doğru cevap verdim" sayacının bekçisi.
///
/// ## Kusur
///
/// Ana ekranın birincil kartı ("Erkê Îro / Dersê rojane") ilerlemesini
/// `MissionType.answerCorrect` görevinden ödünç alıyordu. Günün üç görevi
/// on altı tanımlık havuzdan gün tohumuyla çekilir ve havuzda o türden
/// yalnız üç tanım vardır — çoğu gün hiç seçilmez. O günlerde kart sabah
/// 0/10 açılıyor, oyuncu on soruyu doğru cevaplıyor, XP artıyor, zincir
/// uzuyor ve kart hâlâ 0/10 yazıyordu (2026-08-12 simülatör turu).
///
/// Sessizdi çünkü görev seçilen günlerde her şey çalışıyordu: kusur
/// takvime bağlıydı ve testler görev listesini elle kuruyordu. Bu bekçi
/// tam da o listede `answerCorrect` YOKKEN ölçer.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    DailyMissionStore.resetInstance();
  });

  DailyMission mission(MissionType type, {int target = 1}) =>
      DailyMission(type: type, target: target, coinReward: 10);

  test('doğru cevap görevi olmayan günde de sayaç ilerliyor', () async {
    final store = await DailyMissionStore.loadForTest([
      mission(MissionType.useWildcard),
      mission(MissionType.playCategory),
      mission(MissionType.keepStreak),
    ]);
    expect(store.correctAnswersToday, 0);

    await store.reportQuizCompleted(
      correctAnswers: 7,
      category: 'Ziman',
      streakAlive: true,
    );

    expect(
      store.correctAnswersToday,
      7,
      reason:
          'Sayaç görev listesine bakmadan saymalı; yoksa ana ekranın birincil '
          'kartı o gün hiç kıpırdamaz.',
    );
  });

  test('turlar üst üste toplanıyor', () async {
    final store = await DailyMissionStore.loadForTest([
      mission(MissionType.useWildcard),
    ]);
    await store.reportQuizCompleted(
      correctAnswers: 4,
      category: 'Çand',
      streakAlive: true,
    );
    await store.reportQuizCompleted(
      correctAnswers: 5,
      category: 'Dîrok',
      streakAlive: true,
    );
    expect(store.correctAnswersToday, 9);
  });

  test('sayaç yeniden yüklemede korunuyor', () async {
    final store = await DailyMissionStore.loadForTest([
      mission(MissionType.useWildcard),
    ]);
    await store.reportQuizCompleted(
      correctAnswers: 3,
      category: 'Ziman',
      streakAlive: true,
    );

    DailyMissionStore.resetInstance();
    final reloaded = await DailyMissionStore.load();
    expect(
      reloaded.correctAnswersToday,
      3,
      reason:
          'Uygulama kapanıp açıldığında bugünün ilerlemesi sıfırlanmamalı; '
          'tarih anahtarı görevlerle ortaktır.',
    );
  });

  test('gün dönünce sayaç sıfırlanıyor', () async {
    final store = await DailyMissionStore.loadForTest([
      mission(MissionType.useWildcard),
    ]);
    await store.reportQuizCompleted(
      correctAnswers: 6,
      category: 'Ziman',
      streakAlive: true,
    );

    // Deponun tarih anahtarını dünkü bir güne çevirmek, gün dönümünü
    // saati beklemeden kurar.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('zankurd.missions.date', '2000-01-01');
    DailyMissionStore.resetInstance();

    final reloaded = await DailyMissionStore.load();
    expect(
      reloaded.correctAnswersToday,
      0,
      reason: 'Dünün doğruları bugüne taşınmamalı.',
    );
  });

  test('clear sayacı da temizliyor', () async {
    final store = await DailyMissionStore.loadForTest([
      mission(MissionType.useWildcard),
    ]);
    await store.reportQuizCompleted(
      correctAnswers: 2,
      category: 'Ziman',
      streakAlive: true,
    );
    await store.clear();
    expect(store.correctAnswersToday, 0);
  });
}
