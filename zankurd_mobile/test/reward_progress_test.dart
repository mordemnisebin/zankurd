import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/achievement_store.dart';
import 'package:zankurd_mobile/src/data/badge_service.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/data/reward_progress_snapshot.dart';
import 'package:zankurd_mobile/src/data/sync_manager.dart';
import 'package:zankurd_mobile/src/models/achievement.dart';
import 'package:zankurd_mobile/src/screens/profile_screen.dart';
import 'package:zankurd_mobile/src/widgets/badge_widget.dart';
import 'package:zankurd_mobile/src/widgets/reward_progress_view.dart';

import 'support/widget_test_helpers.dart';

/// Rozet ilerlemesinin bekçisi (2026-10-24).
///
/// ## Kusur
///
/// Kilitli rozet yalnız bir kilitti: "100 soru" rozetine 63'te olmak ile
/// 3'te olmak aynı görünüyordu; açılmış rozetin de ne zaman kazanıldığı
/// yoktu. Rozet bir hedef değil süs kalıyordu.
///
/// ## Niçin sessiz kalırdı
///
/// İlerleme yalnız bir gösterimdir; yanlış hedef sayısı (ör. 100 yerine 50)
/// ya da çubuğun hep boş kalması hiçbir hata üretmez. Bu yüzden her hedef
/// açılma kuralındaki sayıyla bire bir sınanır.
///
/// ## Kural
///
/// Hedefler açılma kurallarıyla AYNI sayıdır; açılış günü açıldığı anda
/// yazılır, eski (tarihsiz) rozette tarih uydurulmaz; kilitli satır çubuk
/// VE `x/y` metni taşır; dar ekranda ve %200 yazıda taşma yok.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    freshMockRepository();
  });
  tearDown(() async => SyncManager.resetForTesting());

  Future<AchievementStore> store() => AchievementStore.load();

  group('AchievementStore.progressFor', () {
    test('hiç oynamamış oyuncu: bütün sayaçlar sıfırdan başlar', () async {
      final s = await store();
      expect(
        s.progressFor(AchievementIds.hundredQuestions),
        const RewardProgress(
          current: 0,
          target: 100,
          unit: RewardUnit.question,
        ),
      );
      expect(
        s.progressFor(AchievementIds.allCategories),
        const RewardProgress(current: 0, target: 11, unit: RewardUnit.topic),
      );
      expect(
        s.progressFor(AchievementIds.sevenDayStreak, dailyStreak: 3),
        const RewardProgress(current: 3, target: 7, unit: RewardUnit.day),
      );
      expect(
        s.progressFor(AchievementIds.dailyQuizFive),
        const RewardProgress(current: 0, target: 5, unit: RewardUnit.round),
      );
      expect(
        s.progressFor(AchievementIds.tenStreak),
        const RewardProgress(current: 0, target: 10),
      );
      expect(
        s.progressFor(AchievementIds.firstGame),
        const RewardProgress(current: 0, target: 1),
      );
      expect(s.progressFor('bilinmeyen'), isNull);
    });

    test('tur sonuçları sayaçları ilerletir (63/100 soru)', () async {
      final s = await store();
      await s.recordQuizResult(
        category: 'Ziman',
        totalQuestions: 63,
        correctCount: 40,
        bestStreak: 6,
        dailyStreak: 2,
        userScore: 0,
      );
      final q = s.progressFor(AchievementIds.hundredQuestions)!;
      expect(q.current, 63);
      expect(q.target, 100);
      expect(q.label(false), '63/100 soru');
      expect(q.label(true), '63/100 pirs');
      expect(q.fraction, closeTo(0.63, 1e-9));
      expect(s.progressFor(AchievementIds.tenStreak)!.current, 6);
      expect(s.progressFor(AchievementIds.allCategories)!.current, 1);
      // En uzun seri düşmez: daha kısa tur geçmişi silmez.
      await s.recordQuizResult(
        category: 'Çand',
        totalQuestions: 5,
        correctCount: 1,
        bestStreak: 2,
        dailyStreak: 2,
        userScore: 0,
      );
      expect(s.progressFor(AchievementIds.tenStreak)!.current, 6);
      expect(s.progressFor(AchievementIds.allCategories)!.current, 2);
    });

    test('açılan başarı hedefe oturur ve gün tarihi yazılır', () async {
      final s = await store();
      await s.recordQuizResult(
        category: 'Ziman',
        totalQuestions: 120,
        correctCount: 100,
        bestStreak: 11,
        dailyStreak: 0,
        userScore: 0,
        now: DateTime(2026, 10, 24, 15),
      );
      expect(s.isUnlocked(AchievementIds.hundredQuestions), isTrue);
      final done = s.progressFor(AchievementIds.hundredQuestions)!;
      expect(done.isComplete, isTrue);
      expect(done.current, 100, reason: '120 cevap olsa da çubuk 100/100');
      expect(s.progressFor(AchievementIds.tenStreak)!.isComplete, isTrue);
      expect(
        s.unlockedAt(AchievementIds.hundredQuestions),
        DateTime(2026, 10, 24),
      );
      expect(s.unlockedAt(AchievementIds.sevenDayStreak), isNull);
    });

    test('günün turu sayacı günde en çok bir kez artar', () async {
      final s = await store();
      for (var i = 0; i < 3; i++) {
        await s.recordQuizResult(
          category: 'Tevlihev',
          totalQuestions: 10,
          correctCount: 5,
          bestStreak: 1,
          dailyStreak: 0,
          userScore: 0,
          dailyQuiz: true,
          now: DateTime(2026, 10, 24, 9 + i),
        );
      }
      expect(s.progressFor(AchievementIds.dailyQuizFive)!.current, 1);
    });

    test(
      'tarih kaydı yeniden yüklemede korunur; eski rozette tarih yok',
      () async {
        final s = await store();
        await s.recordQuizResult(
          category: 'Ziman',
          totalQuestions: 1,
          correctCount: 1,
          bestStreak: 1,
          dailyStreak: 0,
          userScore: 0,
          now: DateTime(2026, 10, 20),
        );
        AchievementStore.resetInstance();
        final again = await AchievementStore.load();
        expect(
          again.unlockedAt(AchievementIds.firstGame),
          DateTime(2026, 10, 20),
        );

        // Tarih anahtarı eklenmeden önce açılmış rozet: tarih uydurulmaz.
        SharedPreferences.setMockInitialValues({});
        AchievementStore.resetInstance();
        final fresh = await AchievementStore.load();
        expect(fresh.unlockedAt(AchievementIds.firstGame), isNull);
      },
    );
  });

  group('BadgeService.progressFor', () {
    test('soru ve zincir rozetleri sayaçlıdır, beceri rozetleri 0/1', () async {
      final badges = await BadgeService.load();
      expect(
        badges.progressFor(
          'questions_500',
          answeredQuestions: 63,
          dailyStreak: 4,
        ),
        const RewardProgress(
          current: 63,
          target: 500,
          unit: RewardUnit.question,
        ),
      );
      expect(
        badges.progressFor(
          'questions_1000',
          answeredQuestions: 63,
          dailyStreak: 4,
        ),
        const RewardProgress(
          current: 63,
          target: 1000,
          unit: RewardUnit.question,
        ),
      );
      expect(
        badges.progressFor('streak_30', answeredQuestions: 63, dailyStreak: 4),
        const RewardProgress(current: 4, target: 30, unit: RewardUnit.day),
      );
      expect(
        badges.progressFor(
          'perfect_game',
          answeredQuestions: 0,
          dailyStreak: 0,
        ),
        const RewardProgress(current: 0, target: 1),
      );
      expect(
        badges.progressFor('yok', answeredQuestions: 0, dailyStreak: 0),
        isNull,
      );
    });

    test('rozet açılınca tarih yazılır ve çubuk dolar', () async {
      final badges = await BadgeService.load();
      await badges.evaluateQuestionBadges(600);
      expect(badges.isUnlocked('questions_500'), isTrue);
      expect(badges.unlockedAt('questions_500'), isNotNull);
      expect(
        badges
            .progressFor(
              'questions_500',
              answeredQuestions: 600,
              dailyStreak: 0,
            )!
            .isComplete,
        isTrue,
      );
      expect(badges.unlockedAt('questions_1000'), isNull);
    });
  });

  test('anlık görüntü iki deponun kimliklerini tek haritada toplar', () async {
    final a = await store();
    await a.recordQuizResult(
      category: 'Ziman',
      totalQuestions: 63,
      correctCount: 40,
      bestStreak: 6,
      dailyStreak: 0,
      userScore: 0,
    );
    final snapshot = await RewardProgressSnapshot.load(
      achievements: a,
      badges: await BadgeService.load(),
      dailyStreak: 5,
    );
    expect(snapshot.progress[AchievementIds.hundredQuestions]!.current, 63);
    expect(snapshot.progress['questions_500']!.current, 63);
    expect(snapshot.progress['streak_30']!.current, 5);
    expect(snapshot.progress[AchievementIds.sevenDayStreak]!.current, 5);
    expect(
      snapshot.progress.length,
      AchievementStore.definitions.length +
          BadgeService.badgeDefinitions.length,
    );
  });

  group('görünüm', () {
    for (final ku in [false, true]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets(
          'rozet karosu 104 px: çubuk + x/y taşmaz (${ku ? 'ku' : 'tr'} @$scale)',
          (tester) async {
            await tester.pumpWidget(
              testShell(
                languageProvider: ku ? kurmanciLang() : null,
                child: Builder(
                  builder: (context) => MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(textScaler: TextScaler.linear(scale)),
                    child: Scaffold(
                      body: Center(
                        child: SizedBox(
                          width: 98,
                          height: 98 / 0.76,
                          child: BadgeWidget(
                            badgeId: 'questions_1000',
                            titleKu: '1000 pirs',
                            titleTr: '1000 soru',
                            descriptionKu: '',
                            descriptionTr: '',
                            iconName: 'military_tech',
                            isUnlocked: false,
                            isKu: ku,
                            progress: const RewardProgress(
                              current: 763,
                              target: 1000,
                              unit: RewardUnit.question,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            expect(
              find.byKey(const ValueKey('reward-progress-bar')),
              findsOneWidget,
            );
            expect(
              find.text(ku ? '763/1000 pirs' : '763/1000 soru'),
              findsOneWidget,
            );
          },
        );
      }
    }

    testWidgets('açılmış rozet karosu tarihi yazar', (tester) async {
      await tester.pumpWidget(
        testShell(
          child: Scaffold(
            body: Center(
              child: SizedBox(
                width: 98,
                height: 98 / 0.76,
                child: BadgeWidget(
                  badgeId: 'perfect_game',
                  titleKu: 'Bêkêmasî',
                  titleTr: 'Kusursuz',
                  descriptionKu: '',
                  descriptionTr: '',
                  iconName: 'stars',
                  isUnlocked: true,
                  isKu: false,
                  progress: const RewardProgress(current: 1, target: 1),
                  unlockedOn: DateTime(2026, 10, 4),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('04.10.2026'), findsOneWidget);
      // Açılmışta çubuk yok: tarih var.
      expect(find.byKey(const ValueKey('reward-progress-bar')), findsNothing);
    });

    test('tarih biçimi gün.ay.yıl', () {
      expect(formatRewardDate(DateTime(2026, 1, 5)), '05.01.2026');
    });
  });

  group('profil: Tüm başarılar', () {
    Future<void> openSheet(WidgetTester tester) async {
      await tester.pumpWidget(
        testShell(
          child: Scaffold(
            body: ProfileScreen(repository: MockZanKurdRepository()),
          ),
        ),
      );
      final rewards = find.byKey(const ValueKey('profile-rewards-card'));
      for (var i = 0; i < 60 && rewards.evaluate().isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.ensureVisible(rewards);
      await tester.tap(rewards);
      await tester.pumpAndSettle();
    }

    testWidgets('kilitli satırda 63/100 soru, açılmışta tarih görünür', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      final a = await store();
      await a.recordQuizResult(
        category: 'Ziman',
        totalQuestions: 63,
        correctCount: 40,
        bestStreak: 3,
        dailyStreak: 0,
        userScore: 0,
        now: DateTime(2026, 10, 24),
      );

      await openSheet(tester);

      expect(find.text('63/100 soru'), findsOneWidget);
      expect(find.text('1/11 konu'), findsOneWidget);
      expect(find.text('Kazanıldı: 24.10.2026'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
