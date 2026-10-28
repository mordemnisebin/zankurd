import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/config/retired_question_ids.dart';
import 'package:zankurd_mobile/src/data/achievement_store.dart';
import 'package:zankurd_mobile/src/data/learner_lexicon.dart';
import 'package:zankurd_mobile/src/data/learning_goal_store.dart';
import 'package:zankurd_mobile/src/data/local_progress_scope.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/data/placement_store.dart';
import 'package:zankurd_mobile/src/data/question_bank_loader.dart';
import 'package:zankurd_mobile/src/data/story_progress_store.dart';
import 'package:zankurd_mobile/src/data/streak_store.dart';
import 'package:zankurd_mobile/src/data/word_list_store.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/models/learning_goal.dart';
import 'package:zankurd_mobile/src/models/mini_guide.dart';
import 'package:zankurd_mobile/src/models/player.dart';
import 'package:zankurd_mobile/src/models/question_metadata.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/models/room.dart';
import 'package:zankurd_mobile/src/models/story.dart';
import 'package:zankurd_mobile/src/screens/home/daily_missions_card.dart';
import 'package:zankurd_mobile/src/screens/home_screen.dart';
import 'package:zankurd_mobile/src/screens/quiz_result_screen.dart';
import 'package:zankurd_mobile/src/screens/room_result_recovery_screen.dart';
import 'package:zankurd_mobile/src/screens/story_screen.dart';
import 'package:zankurd_mobile/src/screens/word_drill_screen.dart';
import 'package:zankurd_mobile/src/services/analytics_service.dart';
import 'package:zankurd_mobile/src/services/placement_scoring.dart';
import 'package:zankurd_mobile/src/services/quiz_reward_settlement_service.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';

import '../tool/question_quality/src/checks.dart';
import '../tool/question_quality/src/models.dart';
import 'support/widget_test_helpers.dart';

Widget _wrap(Widget child) => MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => LanguageProvider()..setLang('tr')),
  ],
  child: MaterialApp(
    theme: AppTheme.dark(),
    home: Scaffold(body: child),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    freshMockRepository();
    LocalProgressScope.debugReset();
    StoryProgressStore.resetInstance();
    StreakStore.resetInstance();
    PlacementStore.resetInstance();
    LearningGoalStore.resetInstance();
    WordListStore.resetInstance();
    AchievementStore.resetInstance();
  });

  tearDown(() => AnalyticsService.instance.debugEventSink = null);

  test(
    'shoppingGuide ve tüm everydayGuides kelimeleri (15/15) sözlükle eşleşir',
    () {
      final words = shoppingGuide.newWords.map((w) => w.ku).toList();
      expect(words, contains('biha'));
      expect(words, isNot(contains('bihâ')));
      expect(LearnerLexicon.lookup('biha')?.id, 'biha');
      expect(LearnerLexicon.lookup('şekir')?.id, 'q-sekir');
      expect(LearnerLexicon.lookup('xizmetkar')?.id, 'q-xizmetkar');
      expect(LearnerLexicon.lookup('kîlo')?.id, 'q-kilo');
      expect(LearnerLexicon.lookup('li kêleka')?.id, 'q-li-keleka');
      for (final guide in everydayGuides.values) {
        for (final w in guide.newWords) {
          expect(LearnerLexicon.lookup(w.ku), isNotNull, reason: w.ku);
        }
      }
    },
  );

  test('soru bankasında needsReview durumunda bekleyen soru kalmaz', () {
    final pending = QuestionBankLoader.instance.allQuestions
        .where((q) => q.metadata?.reviewStatus == ReviewStatus.needsReview)
        .map((q) => q.id)
        .toList();
    expect(pending, isEmpty);
  });

  test(
    'logQuizStart ve logQuizComplete round_id parametresini taşır',
    () async {
      final events = <(String, Map<String, Object>?)>[];
      AnalyticsService.instance.debugEventSink = (name, params) {
        events.add((name, params));
      };
      await AnalyticsService.instance.logQuizStart(
        category: 'Ziman',
        mode: 'solo',
        roundId: 'r-123',
      );
      await AnalyticsService.instance.logQuizComplete(
        category: 'Ziman',
        mode: 'solo',
        roundId: 'r-123',
        correctCount: 4,
        totalQuestions: 5,
        xpEarned: 90,
      );
      expect(events.map((e) => e.$1).toList(), ['quiz_start', 'quiz_complete']);
      expect(events[0].$2, {
        'category': 'Ziman',
        'mode': 'solo',
        'round_id': 'r-123',
      });
      expect(events[1].$2, {
        'category': 'Ziman',
        'mode': 'solo',
        'round_id': 'r-123',
        'correct': 4,
        'total': 5,
        'xp': 90,
      });
    },
  );

  test('hat_0062 ve hat_0071 emekli, ds_cografya_0007 oynanabilir kalır', () {
    expect(isQuestionRetired('hat_0062'), isTrue);
    expect(isQuestionRetired('hat_0071'), isTrue);
    expect(isQuestionRetired('ds_cografya_0007'), isFalse);
  });

  test(
    'fillInBlank sorularında ikinci tırnak içi ipucu farklıysa yakın tekrar sayılmaz',
    () {
      const a = QuestionRecord(
        sourceId: 'test',
        sourceRole: SourceRole.runtimePrimary,
        sourcePath: 'test.json',
        sourceFormat: 'json',
        sourceRow: 1,
        sourceRecordId: 'fib_1',
        runtimeId: 'fib_1',
        canonicalId: 'fib_1',
        category: 'Ziman',
        canonicalGroup: 'ziman',
        questionType: 'fillInBlank',
        prompt: 'Hevokê temam bike: "Ev ___ e." ("Bu gül.")',
        options: ['gul', 'mal', 'av', 'nan'],
        correctOptionIndex: 0,
        correctOptionText: 'gul',
      );
      const b = QuestionRecord(
        sourceId: 'test',
        sourceRole: SourceRole.runtimePrimary,
        sourcePath: 'test.json',
        sourceFormat: 'json',
        sourceRow: 2,
        sourceRecordId: 'fib_2',
        runtimeId: 'fib_2',
        canonicalId: 'fib_2',
        category: 'Ziman',
        canonicalGroup: 'ziman',
        questionType: 'fillInBlank',
        prompt: 'Hevokê temam bike: "Ev ___ e." ("Bu ev.")',
        options: ['mal', 'gul', 'av', 'nan'],
        correctOptionIndex: 0,
        correctOptionText: 'mal',
      );
      final issues = runDuplicateChecks(const [a, b]);
      expect(
        issues.where((i) => i.checkId == 'near_duplicate_candidate'),
        isEmpty,
      );
    },
  );

  testWidgets(
    'StoryScreen mini rehberde ve bitiş ekranında kelimeleri WordListStore kuyruğuna kaydeder ve story_complete üretir',
    (tester) async {
      final events = <(String, Map<String, Object>?)>[];
      AnalyticsService.instance.debugEventSink = (name, params) {
        events.add((name, params));
      };
      await tester.pumpWidget(
        _wrap(StoryScreen(story: cayxaneStory, guide: cayxaneGuide)),
      );
      await tester.pumpAndSettle();

      // Mini rehberi aç; 5 kelimenin tamamında (şekir ve xizmetkar dahil) kaydet düğmesi görünür.
      await tester.tap(find.byKey(const ValueKey('story-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('story-open-guide')));
      await tester.pumpAndSettle();
      final saveCayInGuide = find.byKey(const ValueKey('word-save-cay'));
      expect(saveCayInGuide, findsOneWidget);
      expect(find.byKey(const ValueKey('word-save-q-sekir')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('word-save-q-xizmetkar')),
        findsOneWidget,
      );
      await tester.tap(saveCayInGuide);
      await tester.pumpAndSettle();

      final store = await WordListStore.load();
      expect(store.contains('cay'), isTrue);

      // Rehberi kapat, hikâyeyi son düğüme ilerlet ve bitiş kelime kartını + story_complete olayını doğrula.
      await tester.ensureVisible(find.text('Anladım'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Anladım'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bir çay, lütfen.'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Evet, teşekkürler.'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('story-ending-words')), findsOneWidget);
      expect(find.byKey(const ValueKey('word-save-spas')), findsOneWidget);
      final storyComplete = events.firstWhere((e) => e.$1 == 'story_complete');
      expect(storyComplete.$2, {'story_id': 'cayxane', 'node_id': 'end_warm'});
      final streak = await StreakStore.load();
      expect(streak.playedToday(), isTrue);
    },
  );

  testWidgets(
    'WordDrillScreen oturumu bitirince review_complete olayı üretir ve günlük seriyi işler',
    (tester) async {
      final events = <(String, Map<String, Object>?)>[];
      AnalyticsService.instance.debugEventSink = (name, params) {
        events.add((name, params));
      };
      final store = await WordListStore.load();
      await store.add('av', now: DateTime(2026, 10, 20));

      await tester.pumpWidget(_wrap(WordDrillScreen(store: store)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Su'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('word-review-next')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('word-review-done')), findsOneWidget);
      final reviewComplete = events.firstWhere(
        (e) => e.$1 == 'review_complete',
      );
      expect(reviewComplete.$2, {'correct': 1, 'total': 1});
      final streak = await StreakStore.load();
      expect(streak.playedToday(), isTrue);
    },
  );

  testWidgets(
    'RoomResultRecoveryScreen roundId değerini QuizResultScreen ekranına taşır ve boşsa room.id yedeğine düşer',
    (tester) async {
      final repo = _FixedQuestionsMockRepo(const [
        QuizQuestion(
          id: 'q1',
          category: 'Ziman',
          prompt: 'Av',
          promptTr: 'Su',
          answers: ['A', 'B', 'C', 'D'],
          answersTr: ['A', 'B', 'C', 'D'],
          correctAnswer: 'A',
          correctAnswerTr: 'A',
          explanation: 'Ravekirin',
        ),
      ]);
      final userId = repo.currentUserId!;
      final snapshot = RoomResultSnapshot(
        room: GameRoom(
          id: 'room-online-42',
          code: '123456',
          name: 'Oda',
          category: 'Ziman',
          status: RoomStatus.finished,
          questionCount: 1,
          secondsPerQuestion: 15,
          players: [
            Player(id: userId, name: 'Ez', score: 10, state: Player.readyState),
            const Player(
              id: 'opp-1',
              name: 'Hevrik',
              score: 0,
              state: Player.readyState,
            ),
          ],
        ),
        ownPlayerId: userId,
        questionIds: const ['q1'],
        answers: const [
          ResumedAnswer(
            questionId: 'q1',
            questionIndex: 0,
            selectedOptionKey: 'A',
            correctOptionKey: 'A',
            isCorrect: true,
            pointsAwarded: 10,
            responseMs: 800,
          ),
        ],
        winnerId: userId,
        endedReason: 'completed',
        forfeitedBy: null,
        finishedAt: DateTime.utc(2026, 10, 24),
      );
      final events = <(String, Map<String, Object>?)>[];
      AnalyticsService.instance.debugEventSink = (name, params) {
        events.add((name, params));
      };

      await tester.pumpWidget(
        testShell(
          child: RoomResultRecoveryScreen(
            repository: repo,
            snapshot: snapshot,
            expectedUserId: userId,
            roundId: '   ',
            rewardSettlementService: QuizRewardSettlementService(
              repository: repo,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final result = tester.widget<QuizResultScreen>(
        find.byType(QuizResultScreen),
      );
      expect(result.roundId, 'room-online-42');
      final complete = events.firstWhere((e) => e.$1 == 'quiz_complete');
      expect(complete.$2?['round_id'], 'room-online-42');
      expect(complete.$2?['mode'], '1v1');
    },
  );

  test(
    'StoryProgressStore, PlacementStore ve LearningGoalStore kayıtları doğru saklanır',
    () async {
      final story = await StoryProgressStore.load();
      await story.saveNode('cayxane', 'n2');
      await story.markCompleted('cayxane');
      expect(story.currentNodeId('cayxane'), 'n2');
      expect(story.isCompleted('cayxane'), isTrue);

      final placement = await PlacementStore.load();
      await placement.saveResult(PlacementLevel.navin);
      expect(placement.level, PlacementLevel.navin);

      final goal = await LearningGoalStore.load();
      expect(await goal.save(LearningGoal.learnKurmanci), isTrue);
      expect(goal.goal, LearningGoal.learnKurmanci);
    },
  );

  testWidgets(
    'Geri dönen kullanıcıda bekleyen tekrar satırı görev kartının üstünde yer alır',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'zankurd.achievements.unlocked': ['first_game'],
      });
      AchievementStore.resetInstance();
      final words = await WordListStore.load();
      await words.add('av', now: DateTime(2026, 10, 20));

      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        testShell(
          child: HomeScreen(
            repository: MockZanKurdRepository(),
            onOpenPlay: () {},
            onOpenLearning: () async {},
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));

      final reviewRow = find.byKey(const ValueKey('home-review-row'));
      final missions = find.byType(DailyMissionsCard);
      final learnDoor = find.byKey(const ValueKey('home-door-learn'));
      expect(reviewRow, findsOneWidget);
      expect(missions, findsOneWidget);

      final learnBottom = tester.getRect(learnDoor).bottom;
      final reviewTop = tester.getRect(reviewRow).top;
      final missionsTop = tester.getRect(missions).top;
      expect(reviewTop, greaterThanOrEqualTo(learnBottom));
      expect(reviewTop, lessThan(missionsTop));
    },
  );
}

class _FixedQuestionsMockRepo extends MockZanKurdRepository {
  _FixedQuestionsMockRepo(this._questions);

  final List<QuizQuestion> _questions;

  @override
  Future<List<QuizQuestion>> loadRoomQuestions(GameRoom room) async =>
      _questions;
}
