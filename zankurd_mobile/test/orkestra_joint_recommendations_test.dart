import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/config/retired_question_ids.dart';
import 'package:zankurd_mobile/src/data/achievement_store.dart';
import 'package:zankurd_mobile/src/data/learner_lexicon.dart';
import 'package:zankurd_mobile/src/data/local_progress_scope.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/data/story_progress_store.dart';
import 'package:zankurd_mobile/src/data/word_list_store.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/models/mini_guide.dart';
import 'package:zankurd_mobile/src/models/story.dart';
import 'package:zankurd_mobile/src/screens/home/daily_missions_card.dart';
import 'package:zankurd_mobile/src/screens/home_screen.dart';
import 'package:zankurd_mobile/src/screens/story_screen.dart';
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
    WordListStore.resetInstance();
    AchievementStore.resetInstance();
  });

  test('shoppingGuide standart Kurmancî "biha" yazar ve sözlükle eşleşir', () {
    final words = shoppingGuide.newWords.map((w) => w.ku).toList();
    expect(words, contains('biha'));
    expect(words, isNot(contains('bihâ')));
    expect(LearnerLexicon.lookup('biha')?.id, 'biha');
  });

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
    'StoryScreen mini rehberde ve bitiş ekranında kelimeleri WordListStore kuyruğuna kaydeder',
    (tester) async {
      await tester.pumpWidget(
        _wrap(StoryScreen(story: cayxaneStory, guide: cayxaneGuide)),
      );
      await tester.pumpAndSettle();

      // Mini rehberi aç ve "çay" kelimesini kaydet.
      await tester.tap(find.byKey(const ValueKey('story-open-guide')));
      await tester.pumpAndSettle();
      final saveCayInGuide = find.byKey(const ValueKey('word-save-cay'));
      expect(saveCayInGuide, findsOneWidget);
      await tester.tap(saveCayInGuide);
      await tester.pumpAndSettle();

      final store = await WordListStore.load();
      expect(store.contains('cay'), isTrue);

      // Rehberi kapat, hikâyeyi son düğüme ilerlet ve bitiş kelime kartını doğrula.
      await tester.tap(find.text('Anladım'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bir çay, lütfen.'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Evet, teşekkürler.'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('story-ending-words')), findsOneWidget);
      expect(find.byKey(const ValueKey('word-save-spas')), findsOneWidget);
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
