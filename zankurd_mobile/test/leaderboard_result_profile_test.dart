// 2026-09-29 doğallık (K9): podyum basamakları yerine sıra satırları.
// 2026-09-29 doğallık: arayüz metni sabitleyen beklentiler yeni metne göre güncellendi.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/data/achievement_store.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/models/leaderboard_entry.dart';
import 'package:zankurd_mobile/src/models/leaderboard_period.dart';
import 'package:zankurd_mobile/src/models/player.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/providers/reduced_motion_provider.dart';
import 'package:zankurd_mobile/src/providers/sound_provider.dart';
import 'package:zankurd_mobile/src/providers/theme_provider.dart';
import 'package:zankurd_mobile/src/screens/favorite_questions_screen.dart';
import 'package:zankurd_mobile/src/screens/leaderboard_screen.dart';
import 'package:zankurd_mobile/src/screens/profile_screen.dart';
import 'package:zankurd_mobile/src/screens/quiz_result_screen.dart';
import 'package:zankurd_mobile/src/screens/quiz_screen.dart';
import 'package:zankurd_mobile/src/services/premium_service.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';
import 'package:zankurd_mobile/main.dart';
import 'support/widget_test_helpers.dart';
import 'package:zankurd_mobile/src/theme/app_icons.dart';
import 'package:zankurd_mobile/src/theme/sahne.dart';

class _EmptyFavoritesRepository extends MockZanKurdRepository {
  @override
  Future<List<QuizQuestion>> loadFavoriteQuestions() async {
    return const [];
  }
}

class _FailingLeaderboardRepository extends MockZanKurdRepository {
  int loadCalls = 0;

  @override
  Future<List<LeaderboardEntry>> loadLeaderboard({
    int limit = 10,
    LeaderboardPeriod period = LeaderboardPeriod.weekly,
  }) {
    loadCalls += 1;
    if (loadCalls > 1) {
      return Future.value(const []);
    }
    return Future<List<LeaderboardEntry>>.delayed(
      Duration.zero,
      () => throw StateError('leaderboard unavailable'),
    );
  }
}

class _EmptyLeaderboardRepository extends MockZanKurdRepository {
  @override
  Future<List<LeaderboardEntry>> loadLeaderboard({
    int limit = 10,
    LeaderboardPeriod period = LeaderboardPeriod.weekly,
  }) async {
    return const [];
  }
}

class _SingleWinnerRepository extends MockZanKurdRepository {
  @override
  Future<List<LeaderboardEntry>> loadLeaderboard({
    int limit = 10,
    LeaderboardPeriod period = LeaderboardPeriod.weekly,
  }) async {
    return const [
      LeaderboardEntry(
        rank: 1,
        playerId: 'winner',
        displayName: 'Bawer',
        totalScore: 110,
        bestStreak: 4,
        roomsPlayed: 1,
      ),
    ];
  }
}

void main() {
  late MockZanKurdRepository repository;
  setUp(() => repository = freshMockRepository());

  testWidgets('leaderboard screen remains usable in landscape', (tester) async {
    await tester.binding.setSurfaceSize(const Size(844, 390));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      testShell(child: LeaderboardScreen(repository: repository)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sıralama'), findsOneWidget);
    expect(find.byIcon(AppIcons.arrowsRotate), findsOneWidget);
  });

  testWidgets('leaderboard lists the top three as ranked rows', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      testShell(child: LeaderboardScreen(repository: repository)),
    );
    await tester.pumpAndSettle();

    // 2026-09-29 doğallık (K9): podyum kalktı; ilk üç de sıra satırıdır ve
    // sırasını satırın başında rakamla yazar.
    for (final rank in [1, 2, 3]) {
      expect(
        find.descendant(
          of: find.byKey(ValueKey('leaderboard-rank-row-$rank')),
          matching: find.text('$rank'),
        ),
        findsOneWidget,
        reason: 'leaderboard-rank-row-$rank',
      );
    }
    expect(find.byKey(const ValueKey('leaderboard-podium')), findsNothing);
  });

  testWidgets('leaderboard podium text stays readable on dark panel', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(844, 390));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      testShell(
        // Bu test kasıtlı koyu panel okunabilirliğini doğrular; açık-varsayılan
        // olsa da burada koyu temayı zorlarız.
        themeProvider: ThemeProvider(initialMode: ThemeMode.dark),
        child: LeaderboardScreen(repository: _SingleWinnerRepository()),
      ),
    );
    await tester.pumpAndSettle();

    final nameText = tester.widget<Text>(find.text('Bawer'));

    // 2026-09-27: podyum artık HER temada aynı koyu sahne zemininde durur
    // (`AppTheme.culturalBrandBg` → `AppTheme.surface`, bkz.
    // `leaderboard_screen.dart` `_Podium`); isim rengi de artık uygulama
    // temasından değil o sahneden gelir ve düz `Colors.white`tır —
    // `AppTheme.textPrimary` (Cream 50, hafif kırık beyaz) eskiden koyu
    // temanın birincil metin rengiydi, şimdi isim onunla değil sahnenin
    // rengiyle eşleşmeli. Sahne kontrastını (≥4.5:1, her iki sahne ucunda)
    // `test/leaderboard_stage_test.dart` ayrıca WCAG ile doğrular.
    //
    // 2026-09-29 Şahnê: sahnenin birincil metni gece belirtecidir
    // (`SahneTokens.night.tx`, kırık beyaz); düz `Colors.white` palet dışı.
    // Koyu temada podyum gece zemininde durur; kontrast ≥ 4.5.
    // 2026-09-29 doğallık (K9): podyum kalktı; ad artık sıra satırında,
    // yine birincil metin.
    expect(nameText.style?.color, equals(SahneTokens.night.tx));
    final l1 = SahneTokens.night.tx.computeLuminance();
    final l2 = SahneTokens.night.bg.computeLuminance();
    expect((l1 + 0.05) / (l2 + 0.05), greaterThanOrEqualTo(4.5));
  });

  testWidgets('leaderboard single winner does not stretch across landscape', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(844, 390));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      testShell(
        child: LeaderboardScreen(repository: _SingleWinnerRepository()),
      ),
    );
    await tester.pumpAndSettle();

    // 2026-09-29 doğallık (K9): podyum basamağı yerine sıra satırı; yatay
    // telefonda (844 < 720 eşiği değil, ama ekran eni 844) liste okunur
    // genişlikte kalır — tek satır ekran boyu gerilmez.
    final rowRect = tester.getRect(
      find.byKey(const ValueKey('leaderboard-rank-row-1')),
    );
    expect(rowRect.width, lessThanOrEqualTo(640));
  });

  testWidgets('profile screen remains usable in landscape', (tester) async {
    await tester.binding.setSurfaceSize(const Size(844, 390));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      testShell(
        child: Scaffold(body: ProfileScreen(repository: repository)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Profil'), findsOneWidget);
    // Dalga 5: başlıktaki dişli ikon kaldırıldı; ayarlar girişi HESAP
    // menüsündeki 'Ayarlar' satırına tekleştirildi.
    expect(find.byKey(const ValueKey('profile-settings-top')), findsNothing);
  });

  testWidgets('opens the leaderboard from the bottom nav', (tester) async {
    await tester.pumpWidget(
      ZanKurdApp(
        repository: repository,
        authProvider: FakeAuthProvider(),
        languageProvider: turkishLang(),
      ),
    );
    await tester.pumpAndSettle();

    // Profil > 'Topluluk ve Ligler' kaldırıldı (Rêz sekmesiyle mükerrerdi,
    // 2026-07-18 Faz 9). Ana yol artık doğrudan alt nav'daki Liderlik sekmesi
    // (KU'da 'Rêz', TR'de 'Sıralama').
    await tester.tap(find.text('Sıralama'));
    await tester.pumpAndSettle();

    // 2026-09-29 doğallık: sekme etiketi ve sayfa başlığı aynı sözcük
    // (sözlük: Sıralama); biri alt çubukta, biri sayfa başında.
    expect(find.text('Sıralama'), findsNWidgets(2));
    expect(find.text('Rojda'), findsWidgets);
  });

  testWidgets('finishes a quiz and opens the result screen', (tester) async {
    final room = repository.createRoom();
    final questions = repository.questions.take(3).toList();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<LanguageProvider>(
            create: (_) => turkishLang(),
          ),
          ChangeNotifierProvider<SoundProvider>(create: (_) => SoundProvider()),
          ChangeNotifierProvider<ReducedMotionProvider>(
            create: (_) => ReducedMotionProvider(),
          ),
          ChangeNotifierProvider<PremiumService>(
            create: (_) => PremiumService.fallback(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: QuizScreen(
            repository: repository,
            room: room,
            questions: questions,
            enableTimer: false,
          ),
        ),
      ),
    );

    Future<void> answerQuestion(
      QuizQuestion question, {
      required bool last,
    }) async {
      // Arayüz Türkçe: şık ekranda `localized(isKu: false)` ile yansıtılıyor.
      // Kurmancî ham cevabı aramak, curated banka çevrilene kadar tesadüfen
      // çalışıyordu (2026-08-10).
      final option = find.ancestor(
        of: find.text(question.localized(isKu: false).correctAnswer),
        matching: find.byType(InkWell),
      );
      await tester.ensureVisible(option.first);
      await tester.pumpAndSettle();
      await tester.tap(option.first);
      await tester.pumpAndSettle();

      final nextButton = last
          ? find.byIcon(AppIcons.flag)
          : find.byIcon(AppIcons.arrowRight);
      // Açıklama paneli yarışma modunda artık gösterilmediği için içerik
      // ekrana sığar; kaydırılabilir alan olmayabilir.
      await tester.ensureVisible(nextButton.last);
      await tester.pumpAndSettle();
      await tester.tap(nextButton.last);
      await tester.pumpAndSettle();
    }

    await answerQuestion(questions[0], last: false);
    await answerQuestion(questions[1], last: false);
    await answerQuestion(questions[2], last: true);

    // 2026-09-29 Şahnê: sonuç ekranı kendi adını ("Sonuç") tekrarlamaz;
    // başlık "Yarış tamamlandı" Manşet biçemindedir (büyük harf etiketi
    // değil).
    expect(find.text('Sonuç'), findsNothing);
    expect(find.text('Yarış tamamlandı'), findsOneWidget);
    expect(find.text('Doğru'), findsOneWidget);
    expect(find.text('Yanlış'), findsOneWidget);

    // Kusursuz turda yeni tur ana eylemdir; seyrek çıkış yolları kapalıdır.
    final replay = find.byKey(const ValueKey('result-play-again-button'));
    for (var i = 0; i < 8 && replay.evaluate().isEmpty; i++) {
      await tester.drag(find.byType(ListView).first, const Offset(0, -500));
      await tester.pumpAndSettle();
    }
    expect(replay, findsOneWidget);

    // Sonuç ana eylemi öğrenme özetinin üstüne taşındığı için kapalı
    // yardımcı yollar artık ListView'un daha aşağısında kalabilir. Test
    // eski piksel sırasını değil, kullanıcı tarafından erişilebilirliği
    // doğrulasın.
    final moreOptions = find.byKey(const ValueKey('result-more-options'));
    for (var i = 0; i < 8 && moreOptions.evaluate().isEmpty; i++) {
      await tester.drag(find.byType(ListView).first, const Offset(0, -500));
      await tester.pumpAndSettle();
    }
    expect(moreOptions, findsOneWidget);
    expect(find.byKey(const ValueKey('result-home-button')), findsNothing);
  });

  testWidgets('result screen compares the player with bot opponents', (
    tester,
  ) async {
    await tester.pumpWidget(
      testShell(
        child: QuizResultScreen(
          repository: repository,
          room: repository.createRoom(),
          score: 230,
          correctCount: 2,
          wrongCount: 1,
          totalQuestions: 3,
          bestStreak: 2,
          answerRecords: const [],
          coinsAwarded: 0,
          opponents: const [
            Player(name: 'Rojda', score: 320, state: 'Bot', streak: 3),
            Player(name: 'Baran', score: 100, state: 'Bot', streak: 1),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Rakiplerle karşılaştır'),
      120,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();

    expect(find.text('Rakiplerle karşılaştır'), findsOneWidget);
    expect(find.text('Sen'), findsOneWidget);
    expect(find.text('Rojda'), findsOneWidget);
    expect(find.text('Baran'), findsOneWidget);
  });

  testWidgets('result screen announces newly unlocked achievements', (
    tester,
  ) async {
    await tester.pumpWidget(
      testShell(
        child: QuizResultScreen(
          repository: repository,
          room: repository.createRoom(),
          score: 1200,
          correctCount: 10,
          wrongCount: 0,
          totalQuestions: 10,
          bestStreak: 10,
          answerRecords: const [],
          coinsAwarded: 0,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Yeni rozet'),
      120,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();

    expect(find.text('Yeni rozet'), findsOneWidget);
    expect(find.text('İlk Oyun'), findsOneWidget);
    expect(find.text('10 Doğru Üst Üste'), findsOneWidget);
  });

  testWidgets('quiz answer feedback labels the correct answer', (tester) async {
    final room = repository.createRoom();
    final question = repository.questions.first;

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<LanguageProvider>(
            create: (_) => turkishLang(),
          ),
          ChangeNotifierProvider<SoundProvider>(create: (_) => SoundProvider()),
          ChangeNotifierProvider<ReducedMotionProvider>(
            create: (_) => ReducedMotionProvider(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: QuizScreen(
            repository: repository,
            room: room,
            questions: [question],
            enableTimer: false,
            // Tur içi açıklama yalnız Öğrenme Bölgesi'nde gösterilir.
            experience: QuizExperience.learning,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final option = find.ancestor(
      of: find.text(question.correctAnswer),
      matching: find.byType(InkWell),
    );
    await tester.tap(option.first);
    await tester.pumpAndSettle();

    // 2026-08-19: "Doğru cevap" kutusu çoktan seçmeli sorulardan
    // kaldırıldı — doğru şık zaten yeşile dönüp tik alıyordu, kutu aynı
    // bilgiyi ikinci kez söyleyip kıt olan dikey alanı kaplıyordu
    // (uygulama sahibinin bildirimi). Kutu yalnız kelime sıralamada
    // kalır; orada doğru dizilimi açan başka hiçbir şey yok
    // (bkz. `needsAnswerRevealFallback`, `lesson_explanation_test`).
    // Korunan asıl kural DEĞİŞMEDİ: açıklama METNİ tur içinde açılmaz.
    expect(find.text('Doğru cevap'), findsNothing);
    // 2026-07-26: açıklama metni tur içinde gösterilmez; sonuç ekranında
    // hepsi bir arada gelir.
    expect(
      find.textContaining(question.getLocalizedExplanation(false)),
      findsNothing,
    );
  });

  testWidgets('favorite questions uses the shared empty state', (tester) async {
    await tester.pumpWidget(
      testShell(
        child: FavoriteQuestionsScreen(repository: _EmptyFavoritesRepository()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('app-empty-state')), findsOneWidget);
    expect(find.text('Henüz kaydedilmiş soru yok.'), findsOneWidget);
  });

  testWidgets('profil mobil düzende 6 menü öğesinin tamamını gösterir', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      testShell(
        child: Scaffold(body: ProfileScreen(repository: repository)),
      ),
    );
    // pumpAndSettle bazen sonsuz progress indicator animasyonunda takılır;
    // profil async yüklemesini sabit karelerle bekle.
    await tester.pump();
    for (var i = 0; i < 30 && find.text('Mağaza').evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(find.text('Kaydedilen sorular'), findsOneWidget);
    expect(find.text('Yanlışlarım'), findsOneWidget);
    // 2026-09-29 Şahnê: bölüm başlığı tek biçemdir (`SahneSectionHeader`,
    // Manşet 22) — büyük harf etiketi değil.
    expect(find.text('Öğrenme'), findsOneWidget);
    expect(find.text('Hesap'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Mağaza'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Mağaza'), findsOneWidget);
    // Arkadaşlar ekranı donduruldu; menüde görünmez.
    expect(find.text('Arkadaşlarım'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('Çıkış yap'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Çıkış yap'), findsOneWidget);
    expect(find.text('Ayarlar'), findsOneWidget);
  });

  testWidgets('profile screen shows unlocked achievement showcase', (
    tester,
  ) async {
    // 2026-07-22 canlı UX denetimi: rozet birleştirme test güncellemesi
    final store = await AchievementStore.load();
    await store.recordQuizResult(
      category: 'Ziman',
      totalQuestions: 3,
      correctCount: 2,
      bestStreak: 2,
      dailyStreak: 1,
      userScore: 230,
    );

    await tester.pumpWidget(
      testShell(
        child: Scaffold(body: ProfileScreen(repository: repository)),
      ),
    );
    await tester.pumpAndSettle();

    // M13: _AchievementShowcase + BadgeCollectionSection → _UnifiedRewardsSection
    // başlık artık 'Başarılar' (eski 'Rozetler' değil).
    await tester.scrollUntilVisible(
      find.text('Başarılar'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('Başarılar'), findsOneWidget);
    expect(find.text('İlk Oyun'), findsOneWidget);
  });

  testWidgets('profile reloads achievements when refresh signal fires', (
    tester,
  ) async {
    final refresh = ValueNotifier<int>(0);
    addTearDown(refresh.dispose);

    await tester.pumpWidget(
      testShell(
        child: Scaffold(
          body: ProfileScreen(repository: repository, refreshSignal: refresh),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Profil açıldığında henüz rozet yok.
    expect(find.text('İlk Oyun'), findsNothing);

    // Profil tabı dışındayken bir quiz tamamlanıp rozet açılmış gibi yap.
    final store = await AchievementStore.load();
    await store.recordQuizResult(
      category: 'Ziman',
      totalQuestions: 3,
      correctCount: 2,
      bestStreak: 2,
      dailyStreak: 1,
      userScore: 230,
    );

    // Profil tabına geri dönüş sinyali tetikleyince veriler tazelenmeli.
    refresh.value++;
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('İlk Oyun'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('İlk Oyun'), findsOneWidget);
  });

  testWidgets('leaderboard error state exposes retry', (tester) async {
    final repository = _FailingLeaderboardRepository();

    await tester.pumpWidget(
      testShell(child: LeaderboardScreen(repository: repository)),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('app-error-state')), findsOneWidget);
    expect(find.text('Tekrar dene'), findsOneWidget);
    expect(repository.loadCalls, 1);

    await tester.tap(find.text('Tekrar dene'));
    await tester.pumpAndSettle();

    expect(repository.loadCalls, 2);
  });

  testWidgets('leaderboard empty state can start a quick race', (tester) async {
    final repository = _EmptyLeaderboardRepository();
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      testShell(child: LeaderboardScreen(repository: repository)),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('app-empty-state')), findsOneWidget);
    expect(find.text('Yarışa başla'), findsOneWidget);

    await tester.ensureVisible(find.text('Yarışa başla'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yarışa başla'));
    await tester.pumpAndSettle();

    expect(find.byType(QuizScreen), findsOneWidget);
  });
}
