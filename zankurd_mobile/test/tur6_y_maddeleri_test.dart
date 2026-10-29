import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/local_data_storage.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/data/word_list_store.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/models/answer_record.dart';
import 'package:zankurd_mobile/src/models/async_duel.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/providers/sound_provider.dart';
import 'package:zankurd_mobile/src/screens/async_duel/async_duel_play_screen.dart';
import 'package:zankurd_mobile/src/screens/matchmaking_screen.dart';
import 'package:zankurd_mobile/src/screens/my_words_screen.dart';
import 'package:zankurd_mobile/src/screens/quiz_result_screen.dart';
import 'package:zankurd_mobile/src/screens/quiz_screen.dart';
import 'package:zankurd_mobile/src/screens/tournament_screen.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';
import 'package:zankurd_mobile/src/widgets/arena_kit.dart';
import 'package:zankurd_mobile/src/widgets/sahne/sahne.dart';

import 'support/realistic_device.dart';
import 'support/widget_test_helpers.dart';

/// 2026-10-29 tur 6 — Y maddeleri (jüri: Claude Opus, Fable, Haiku,
/// claude.ai Opus; her madde en az 2 jüri üyesinin ortak bulgusu).
///
/// ## Kusurlar ve niçin sessiz kalırlardı
///
/// * **Y1 sonuç ekranı:** "Cevapları gör (1 yanlış)" turuncu METİN bağlantısıydı
///   (turuncu dolu "Tekrar oyna" ile iki turuncu eylem), "Ayrıntılar 3" neyin
///   sayısı olduğunu söylemiyordu, kutusuz "Diğer seçenekler ⌄" havada
///   duruyordu. Hiçbiri taşma/çökme değildi; yalnız hiyerarşi bozuktu, bu
///   yüzden hiçbir işlevsel test kırılmadı.
/// * **Y3 sırayla düello sorusu:** "Sen oyna, rakip sonra" satırı soru
///   kartının ÜSTÜNDE gövdede duruyordu; dengeli yerleşim kartı ekranın
///   ortasına itiyordu. Aynı soru yarış/ders ekranında üstteydi.
/// * **Y4 eşleşme:** tek birincil eylem 44 px'lik turuncu ok karesiydi.
/// * **Y5/Y6:** turuncu/altın/yeşil eylem dışı anlamlarla kullanılıyordu.
/// * **Y7 turnuva:** "dolmazsa 24 saat içinde eldeki oyuncularla başlar"
///   sunucu kuralına (24 saat sonra EN AZ 2 oyuncu, yoksa bekler) uymuyordu.
///
/// Renk ve düzen kusurları yalnız gözle yakalanır; bu dosya o gözün kuralını
/// sabitler.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadAppFonts);

  // ──────────────────────────── Y1 ────────────────────────────
  group('Y1 sonuç ekranı alt alanı', () {
    List<AnswerRecord> records(int wrong) => [
      for (var i = 0; i < 4; i++)
        AnswerRecord(
          id: 'r$i',
          category: i.isEven ? 'Ziman' : 'Dîrok',
          prompt: 'Pirs $i',
          answers: const ['A', 'B'],
          correctAnswer: 'A',
          selectedAnswer: i < wrong ? 'B' : 'A',
          explanation: 'Şirove',
          explanationTr: 'Bu sorunun açıklaması $i numaralı satırdadır.',
        ),
    ];

    Future<void> pumpResult(
      WidgetTester tester, {
      required int wrong,
      Size size = const Size(390, 844),
    }) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.reset);
      final repository = freshMockRepository();
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        testShell(
          child: QuizResultScreen(
            repository: repository,
            room: repository.createRoom(),
            score: (4 - wrong) * 100,
            correctCount: 4 - wrong,
            wrongCount: wrong,
            totalQuestions: 4,
            bestStreak: 1,
            coinsAwarded: 0,
            answerRecords: records(wrong),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
    }

    testWidgets('tek turuncu dolu düğme; "Cevapları gör" çerçeveli, tam '
        'genişlik, rozetli', (tester) async {
      await pumpResult(tester, wrong: 1);
      expect(
        find.byWidgetPredicate((w) => w is SahneButton && w.isPrimary),
        findsOneWidget,
        reason: 'ekranda tek dolu birincil',
      );

      final see = find.byKey(const ValueKey('result-see-answers-button'));
      expect(see, findsOneWidget);
      final seeButton = tester.widget<SahneButton>(
        find.descendant(of: see, matching: find.byType(SahneButton)),
      );
      expect(seeButton.isPrimary, isFalse);
      // Çerçeveli ikincil: dolgu şeffaf.
      final filled = tester.widget<FilledButton>(
        find.descendant(of: see, matching: find.byType(FilledButton)),
      );
      expect(
        filled.style!.backgroundColor!.resolve(<WidgetState>{}),
        Colors.transparent,
      );
      // Tam genişlik (>= 290 @390).
      expect(tester.getSize(see).width, greaterThan(290));
      // Yanlış sayısı rozet.
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('result-see-answers-badge')),
          matching: find.text(
            '1 yanlış',
          ), // 2026-10-29 son kurul: rozet birimli
        ),
        findsOneWidget,
      );
      // Birincil, çerçeveli düğmenin ALTINDA.
      final primary = tester.getRect(
        find.byKey(const ValueKey('result-play-again-button')).first,
      );
      expect(tester.getRect(see).bottom, lessThanOrEqualTo(primary.top + 1));
    });

    testWidgets('"Diğer seçenekler" satırı yok; "⋯" alt perdede, sayfa '
        'ana sayfa/sıralama/değerlendir verir', (tester) async {
      await pumpResult(tester, wrong: 1);
      expect(find.text('Diğer seçenekler'), findsNothing);
      final more = find.byKey(const ValueKey('result-more-options'));
      expect(more, findsOneWidget);
      expect(tester.getSize(more).width, lessThanOrEqualTo(64));
      expect(tester.getSize(more).height, greaterThanOrEqualTo(48));
      final primary = tester.getRect(
        find.byKey(const ValueKey('result-play-again-button')).first,
      );
      expect(
        (tester.getCenter(more).dy - primary.center.dy).abs(),
        lessThan(8),
      );
      expect(find.byKey(const ValueKey('result-home-button')), findsNothing);
      await tester.tap(more);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('result-home-button')), findsOneWidget);
      expect(find.text('Sıralama'), findsOneWidget);
      expect(find.byKey(const ValueKey('result-rate-button')), findsOneWidget);
    });

    testWidgets('katlanan bölüm birimli adlanır: "Ayrıntılar · N konu"', (
      tester,
    ) async {
      await pumpResult(tester, wrong: 1);
      final header = find.byKey(const ValueKey('result-collapsible-header'));
      expect(
        find.descendant(of: header, matching: find.text('Ayrıntılar · 2 konu')),
        findsOneWidget,
      );
      expect(find.text('Ayrıntılar'), findsNothing);
    });

    testWidgets('320 pt + %200 yazıda taşma yok', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpResult(tester, wrong: 2, size: const Size(320, 700));
      expect(tester.takeException(), isNull);
      expect(
        find.byKey(const ValueKey('result-play-again-button')),
        findsWidgets,
      );
    });
  });

  // ──────────────────────────── Y3 ────────────────────────────
  group('Y3 soru kartı her modda aynı yerde', () {
    testWidgets('sırayla düello kartı yarış/ders sahnesiyle ±8 px aynı üstte; '
        '"Sen oyna, rakip sonra" üst çubukta', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      tester.view.padding = const FakeViewPadding(top: 47, bottom: 34);
      tester.view.viewPadding = const FakeViewPadding(top: 47, bottom: 34);
      addTearDown(tester.view.reset);

      final repo = freshMockRepository();
      await tester.pumpWidget(
        testShell(
          child: AsyncDuelPlayScreen(
            repository: repo,
            entry: const AsyncDuelEntry.createChallenge(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      final duelCard = find.byKey(const ValueKey('quiz-prompt-card'));
      expect(duelCard, findsOneWidget);
      var optionCount = 0;
      while (find
          .byKey(ValueKey('async-duel-option-$optionCount'))
          .evaluate()
          .isNotEmpty) {
        optionCount++;
      }
      final duelTop = tester.getTopLeft(duelCard).dy;

      // Alt satır üst çubukta: soru kartının üstünde.
      final sub = find.byKey(const ValueKey('quiz-stage-subtitle'));
      expect(sub, findsOneWidget);
      expect(find.text('Sen oyna, rakip sonra'), findsOneWidget);
      expect(tester.getRect(sub).bottom, lessThanOrEqualTo(duelTop));

      // Aynı sayıda şıklı soruyla her soru modu.
      // AYNI soru ve şıklar (kart boyu denge kuralını etkiler).
      String lastText(Finder scope) => tester
          .widgetList<Text>(
            find.descendant(of: scope, matching: find.byType(Text)),
          )
          .map((w) => w.data ?? '')
          .where((d) => d.isNotEmpty)
          .last;
      final answers = [
        for (var i = 0; i < optionCount; i++)
          lastText(find.byKey(ValueKey('async-duel-option-$i'))),
      ];
      final q = QuizQuestion(
        id: 'y3',
        category: 'Cîhan',
        prompt: lastText(duelCard),
        answers: answers,
        correctAnswer: answers.first,
        explanation: 'x',
      );
      final repo2 = freshMockRepository();
      for (final experience in QuizExperience.values) {
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(
          testShell(
            child: QuizScreen(
              repository: repo2,
              room: repo2.createRoom(),
              questions: [q, q],
              experience: experience,
              enableTimer: false,
            ),
          ),
        );
        await tester.pumpAndSettle();
        final card = find.byKey(const ValueKey('quiz-prompt-card'));
        expect(card, findsOneWidget);
        expect(
          (tester.getTopLeft(card).dy - duelTop).abs(),
          lessThanOrEqualTo(8),
          reason:
              '$experience: soru kartı üstü ${tester.getTopLeft(card).dy} ≠ '
              'düello $duelTop (±8)',
        );
      }
    });
  });

  // ──────────────────────────── Y4 ────────────────────────────
  group('Y4 eşleşme', () {
    Widget shell(Widget child) => MultiProvider(
      providers: [
        ChangeNotifierProvider<LanguageProvider>(
          create: (_) => LanguageProvider()..setLang('tr'),
        ),
        ChangeNotifierProvider<SoundProvider>(create: (_) => SoundProvider()),
      ],
      child: MaterialApp(theme: AppTheme.light(), home: child),
    );

    // 2026-10-29 vay 2A: konu SATIRLARI (nötr + › + 4 px şerit) yerine TRT
    // "Kategorini seç" gibi doygun kategori karoları (Astra: "ayarlar
    // listesine benziyor"); tek turuncu birincil kuralı aynı.
    testWidgets('"Rastgele rakip bul" tam genişlik tek birincil, altta sabit; '
        'konular doygun karolar', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        shell(MatchmakingScreen(repository: MockZanKurdRepository())),
      );
      await tester.pumpAndSettle();

      final cta = find.byKey(const ValueKey('matchmaking-random-cta'));
      expect(cta, findsOneWidget);
      expect(find.text('Rastgele rakip bul'), findsOneWidget);
      expect(tester.getSize(cta).width, greaterThanOrEqualTo(390 - 32 - 1));
      expect(tester.getSize(cta).height, greaterThanOrEqualTo(48));
      expect(
        find.byWidgetPredicate((w) => w is SahneButton && w.isPrimary),
        findsOneWidget,
      );
      expect(tester.getRect(cta).bottom, greaterThan(844 * 0.8));

      expect(find.byType(SahnePickTile), findsWidgets);
      expect(find.byType(SahneListRow), findsNothing);
    });
  });

  // ──────────────────────────── Y5 ────────────────────────────
  group('Y5 eylem dışı turuncu temizliği', () {
    testWidgets('SahneButton.text(ink) mürekkep rengi, turuncu değil', (
      tester,
    ) async {
      await tester.pumpWidget(
        testShell(
          child: Scaffold(
            body: Column(
              children: [
                SahneButton.text(
                  key: const ValueKey('plain'),
                  label: 'a',
                  onPressed: () {},
                ),
                SahneButton.text(
                  key: const ValueKey('inked'),
                  label: 'b',
                  ink: true,
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ),
      );
      final t = SahneTokens.of(
        tester.element(find.byKey(const ValueKey('plain'))),
      );
      Color fg(String key) => tester
          .widget<TextButton>(
            find.descendant(
              of: find.byKey(ValueKey(key)),
              matching: find.byType(TextButton),
            ),
          )
          .style!
          .foregroundColor!
          .resolve(<WidgetState>{})!;
      expect(fg('plain'), t.linkTx);
      expect(fg('inked'), t.tx);
      expect(fg('inked'), isNot(t.linkTx));
    });

    String src(String path) => File(path).readAsStringSync();

    test('ikincil bağlantılar mürekkep, hikâye göz başlığı Öğren yeşili', () {
      expect(
        src('lib/src/screens/learning_screen.dart'),
        contains(
          'label: context.t(K.placementCardStart),\n            ink: true,',
        ),
        reason: '"Teste başla" turuncu metin olmamalı',
      );
      expect(
        src('lib/src/screens/profile_name_gate_screen.dart'),
        contains('label: context.t(K.nameGateSkip),\n        ink: true,'),
        reason: '"Şimdilik geç" turuncu metin olmamalı',
      );
      // 2026-10-29 vay 2B (B7): bağlantı artık koyu kimlik kartında BEYAZ
      // kalemli bağlantı (`_OnCardLink`); yine turuncu değil.
      final profile = src('lib/src/screens/profile/profile_widgets.dart');
      expect(
        profile,
        contains("key: const ValueKey('profile-set-name-cta'),"),
        reason: '"Oyundaki adını gir" bağlantısı duruyor',
      );
      expect(
        profile,
        contains('_OnCardLink(\n                          key'),
        reason: '"Oyundaki adını gir" turuncu metin olmamalı',
      );
      final story = src('lib/src/screens/story_screen.dart');
      expect(story, contains('color: s.learnTx'));
      expect(story, isNot(contains('color: s.eyebrowTx,')));
    });

    test('çark satırı altın çip + chevron', () {
      final hub = src('lib/src/screens/play_hub_screen.dart');
      expect(hub, contains('tone: SahneBadgeTone.gold'));
      expect(hub, contains('chevron: true,\n      semanticLabel: ['));
      expect(hub, isNot(contains('chevron: !_spinReady')));
    });

    testWidgets('Günün turu pili nötr (s1 zemin, tx metin)', (tester) async {
      await tester.pumpWidget(
        testShell(
          child: const Scaffold(
            body: Center(
              child: ArenaStatusChip(
                status: ArenaStatus.live,
                label: 'Bugün oynanabilir',
                onSolid: true,
                role: SahneRole.neutral,
              ),
            ),
          ),
        ),
      );
      final t = SahneTokens.of(tester.element(find.byType(Scaffold)));
      final deco =
          tester
                  .widget<DecoratedBox>(
                    find
                        .ancestor(
                          of: find.text('Bugün oynanabilir'),
                          matching: find.byType(DecoratedBox),
                        )
                        .first,
                  )
                  .decoration
              as ShapeDecoration;
      expect(deco.color, t.s1);
      expect(deco.color, isNot(t.raceTint));
      expect(
        tester.widget<Text>(find.text('Bugün oynanabilir')).style!.color,
        t.tx,
      );
      // Ekran gerçekten nötr rolü kullanır.
      expect(
        src('lib/src/screens/contest_screen.dart'),
        contains('role: SahneRole.neutral'),
      );
    });
  });

  // ──────────────────────────── Y6 ────────────────────────────
  group('Y6 Kelimelerim', () {
    testWidgets('yer imi Öğren yeşili (altın değil); "Tekrar zamanı" nötr', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 3.0;
      tester.view.physicalSize = const Size(390, 800) * 3;
      addTearDown(tester.view.reset);
      final store = await WordListStore.load(storage: InMemoryDataStorage());
      await store.add(
        'rojbas',
        now: DateTime.now().subtract(const Duration(days: 3)),
      );
      await tester.pumpWidget(
        testShell(
          child: MyWordsScreen(
            repository: MockZanKurdRepository(),
            store: store,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final t = SahneTokens.of(tester.element(find.byType(MyWordsScreen)));
      final save = find.byKey(const ValueKey('word-save-rojbas'));
      expect(save, findsOneWidget);
      final plate = tester.widget<SahneTappable>(
        find.descendant(of: save, matching: find.byType(SahneTappable)),
      );
      expect(plate.color, t.learnTint);
      expect(plate.color, isNot(t.goldTint));

      final chip = find.byKey(const ValueKey('my-word-due-chip'));
      expect(chip, findsOneWidget);
      final deco =
          tester.widget<DecoratedBox>(chip).decoration as ShapeDecoration;
      expect(deco.color, t.s2);
      expect(deco.color, isNot(t.okTint));
    });
  });

  // ──────────────────────────── Y7 ────────────────────────────
  group('Y7 turnuva', () {
    testWidgets('hero açıklaması tek satır; sunucu kuralı "Nasıl oynanır" '
        'içinde; yol çipleri birimli', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        testShell(child: TournamentScreen(repository: freshMockRepository())),
      );
      await tester.pumpAndSettle();
      final line = find.text(
        'Dolunca ya da 24 saat sonra en az 2 oyuncuyla başlar',
      );
      expect(line, findsOneWidget);
      // 2026-10-29 Astra: başlama koşulu (en az 2 oyuncu) hero'da da yazılır,
      // bekleme ekranıyla tutarlı olsun diye; dar telefonda İKİ satıra sarar
      // (kesilmez). Tek satır şartı bilerek bu uzunluğa gevşetildi.
      expect(tester.getSize(line).height, lessThan(48));
      // Sunucu kuralına uymayan eski söz hiçbir yerde yok.
      expect(find.textContaining('eldeki oyuncularla başlar'), findsNothing);
      // Yol çipleri birimli.
      // 2026-10-29 vay 2A: yol bir eleme şeması; birimli cümle ekran
      // okuyucuda (bkz. `vay_2a_test`).
      expect(
        find.bySemanticsLabel(RegExp(r'· 4 oyuncu › Final · 2 oyuncu')),
        findsOneWidget,
      );
      expect(find.text('Şampiyon'), findsOneWidget);
      // Sunucu kuralı (24 saat sonra EN AZ 2 oyuncu; yoksa bekler): açılınca.
      await tester.ensureVisible(
        find.byKey(const ValueKey('tournament-rules-toggle')),
      );
      // 2026-10-29 vay 2A: eleme şeması lobiyi uzattı; kural düğmesi artık
      // ilk ekranın altında. `ensureVisible` kaydırır ama çizmez: dokunmadan
      // önce bir kare pompalanır (yoksa eski konuma dokunulur).
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('tournament-rules-toggle')));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Kupa açıldıktan 24 saat sonra en az 2 oyuncu varsa başlar; '
          'yoksa oyuncu beklenir.',
        ),
        findsOneWidget,
      );
    });
  });

  // ──────────────────────────── Y8 ────────────────────────────
  group('Y8 küçükler', () {
    test(
      '"Karışık" karanlıkta zeminden ayrışır; filigran <= %6 ve kırpılı',
      () {
        final mixed = SahneCategoryTone.of('Tevlihev');
        expect(
          mixed.fill(night: true),
          isNot(SahneCategoryTone.fallback.ground),
        );
        expect(mixed.fill(night: true).computeLuminance(), greaterThan(0.12));
        for (final c in [mixed.fill(night: true), mixed.fill(night: false)]) {
          final ratio = 1.05 / (c.computeLuminance() + 0.05);
          expect(ratio, greaterThanOrEqualTo(4.5), reason: 'beyaz ikon/yazı');
        }
        final home = File(
          'lib/src/screens/home/home_sections.dart',
        ).readAsStringSync();
        // 2026-10-29 vay 2A: filigran tamamen kalktı (≤ %6 kuralı artık
        // "hiç yok"); ad + rozet + şerit kartın pahlı kenarında kırpılır.
        expect(home, isNot(contains('home-topic-mark-')));
        expect(home, contains('ClipPath'));
      },
    );

    test('kapalı anahtar nötr gri iz + beyaz topuz', () {
      for (final theme in [AppTheme.light(), AppTheme.dark()]) {
        final off = theme.switchTheme.trackColor!.resolve(<WidgetState>{})!;
        final channels = [off.r, off.g, off.b];
        final spread =
            (channels.reduce((a, b) => a > b ? a : b) -
                channels.reduce((a, b) => a < b ? a : b)) *
            255;
        expect(spread, lessThanOrEqualTo(6), reason: 'R≈G≈B (nötr)');
        final thumb = theme.switchTheme.thumbColor!.resolve(<WidgetState>{})!;
        expect(thumb.computeLuminance(), greaterThan(0.85));
      }
    });

    test('dil seçimi çift dilli başlık bilinçli istisna olarak belgeli', () {
      final strings = File('lib/src/l10n/strings.dart').readAsStringSync();
      expect(strings, contains('TASARIM_DILI "başlık tek dilde" kuralının'));
      expect(
        File('lib/src/widgets/language_picker.dart').readAsStringSync(),
        contains('TASARIM_DILI istisnası'),
      );
    });
  });
}
