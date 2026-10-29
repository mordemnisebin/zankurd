import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/models/tournament.dart';
import 'package:zankurd_mobile/src/providers/reduced_motion_provider.dart';
import 'package:zankurd_mobile/src/providers/sound_provider.dart';
import 'package:zankurd_mobile/src/providers/theme_provider.dart';
import 'package:zankurd_mobile/src/screens/matchmaking_screen.dart';
import 'package:zankurd_mobile/src/screens/quiz/quiz_option_tile.dart';
import 'package:zankurd_mobile/src/screens/quiz_result_screen.dart';
import 'package:zankurd_mobile/src/screens/spin_wheel_screen.dart';
import 'package:zankurd_mobile/src/screens/tournament_screen.dart';
import 'package:zankurd_mobile/src/theme/app_icons.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';
import 'package:zankurd_mobile/src/widgets/quiz_stage_kit.dart';
import 'package:zankurd_mobile/src/widgets/sahne/sahne.dart';
import 'package:zankurd_mobile/src/widgets/zan_mascot.dart';

import 'sahne_widgets/sahne_harness.dart';
import 'support/widget_test_helpers.dart';

/// Vay 2A bekçisi (2026-10-29 vay 2A).
///
/// ## Kusur
///
/// GPT-6 Astra'nın ekran ekran denetimi (çıta rakipler TRT Bil Bakalım,
/// Trivia Crack, Quiz Planet, Duolingo, Clash tarzı braket):
///
/// * yanlış şıkta kırmızı çapraz TARAMA "açıkça kötü görünüyordu";
/// * çarkta siyah/gri dilimler ve "ZK" göbeği hazır bileşen hissi veriyordu;
/// * eşleşmenin kategori seçimi "ayarlar listesi" gibiydi ve son kategori
///   alttaki düğmenin arkasında kalıyordu;
/// * turnuva yolu birkaç sıkışık etiketti, eleme hissi yoktu;
/// * sonuçta kömür grisi "Ayrıntılar" bandı mor sahneden kopuktu;
/// * kabartmalı kartların altında gri ikinci bir plaka (kalın gölge) ve koyu
///   temada çamurlu, kararmış mod kartları vardı.
///
/// ## Neden sessiz kalırdı
///
/// Hepsi saf görseldir: hiçbir akış, hiçbir sayı değişmez. Taramayı geri
/// koyan, çarka `s3` dilimi ekleyen ya da ızgarayı listeye döndüren bir
/// "sadeleştirme" bütün eski testleri yeşil bırakırdı.
///
/// ## Kural
///
/// Aşağıdaki her grup bir Astra bulgusunun düzeltmesini sabitler.
double _lum(Color c) => c.computeLuminance();
double _contrast(Color a, Color b) {
  final l1 = _lum(a);
  final l2 = _lum(b);
  final hi = l1 > l2 ? l1 : l2;
  final lo = l1 > l2 ? l2 : l1;
  return (hi + 0.05) / (lo + 0.05);
}

Widget _shell(Widget child, {bool dark = false, bool ku = false}) =>
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => LanguageProvider()..setLang(ku ? 'ku' : 'tr'),
        ),
        ChangeNotifierProvider(create: (_) => SoundProvider()),
        ChangeNotifierProvider<ReducedMotionProvider>(
          create: (_) => ReducedMotionProvider(),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        home: child,
      ),
    );

Widget _lang(Widget child) => ChangeNotifierProvider<LanguageProvider>(
  create: (_) => LanguageProvider()..setLang('tr'),
  child: child,
);

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await ZanMascot.preloadForTest();
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('yanlış şık: tarama yok, sakin şarap dolgu', () {
    testWidgets('yanlış seçimde çapraz tarama ressamı çizilmez', (
      tester,
    ) async {
      await pumpSahne(
        tester,
        _lang(
          QuizOptionTile(
            index: 3,
            answer: 'kadın',
            selected: true,
            correct: false,
            disabled: true,
            onTap: () {},
          ),
        ),
        dark: true,
        textScale: 1,
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('wrong_icon')), findsOneWidget);
      final hatch = find.byWidgetPredicate(
        (w) =>
            w is CustomPaint &&
            w.painter != null &&
            w.painter.runtimeType.toString().contains('Hatch'),
      );
      expect(hatch, findsNothing, reason: 'kırmızı tarama geri geldi');
      // Yanlış şıkta kabartma tabanı da yok: şık "basılmış" durur.
      final base = tester.widget<DecoratedBox>(
        find.byKey(const ValueKey('quiz-option-base')),
      );
      expect((base.decoration as ShapeDecoration).shadows, isEmpty);
    });

    testWidgets('boştaki şık kabartmalı (koyu taban + ışık)', (tester) async {
      await pumpSahne(
        tester,
        _lang(
          QuizOptionTile(
            index: 0,
            answer: 'özgürlük',
            selected: false,
            correct: false,
            disabled: false,
            onTap: () {},
          ),
        ),
        dark: true,
        textScale: 1,
      );
      final base = tester.widget<DecoratedBox>(
        find.byKey(const ValueKey('quiz-option-base')),
      );
      expect((base.decoration as ShapeDecoration).shadows, isNotEmpty);
      final face = tester.widget<CustomPaint>(
        find.byKey(const ValueKey('quiz-option-face')),
      );
      expect(face.painter, isA<SahneEmbossPainter>());
      expect(
        tester.getSize(find.byType(QuizOptionTile)).height,
        greaterThanOrEqualTo(quizOptionMinHeight),
      );
    });

    test('şarap dolgular üstünde gece metni ≥ 4,5:1', () {
      const t = SahneTokens.night;
      expect(
        _contrast(t.tx, SahneVayColors.optionWrongFill),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrast(t.tx, SahneVayColors.feedbackWrongFill),
        greaterThanOrEqualTo(4.5),
      );
      // Beyaz "Devam et" düğmesinde şeridin rengiyle yazı.
      expect(
        _contrast(SahneVayColors.white, SahneVayColors.feedbackWrongFill),
        greaterThanOrEqualTo(4.5),
      );
    });

    for (final correct in [true, false]) {
      testWidgets('geri bildirim şeridinde mini maskot (correct=$correct)', (
        tester,
      ) async {
        await pumpSahne(
          tester,
          _lang(
            QuizFeedbackStrip(
              correct: correct,
              action: const SizedBox(height: 48),
            ),
          ),
          dark: true,
          textScale: 1,
        );
        await tester.pumpAndSettle();
        final mascot = tester.widget<ZanMascot>(
          find.byKey(const ValueKey('quiz-feedback-mascot')),
        );
        expect(mascot.pose, correct ? ZanPose.correct : ZanPose.wrong);
        expect(mascot.size, inInclusiveRange(44, 56));
        final strip = tester.widget<Container>(
          find.byKey(
            ValueKey(correct ? 'quiz-feedback-correct' : 'quiz-feedback-wrong'),
          ),
        );
        expect(
          (strip.decoration! as ShapeDecoration).color,
          correct ? SahneTokens.night.okFill : SahneVayColors.feedbackWrongFill,
        );
      });
    }

    testWidgets('320 pt ×2: şerit taşmaz, maskot büyük yazıda düşer', (
      tester,
    ) async {
      await pumpSahne(
        tester,
        _lang(
          const QuizFeedbackStrip(
            correct: false,
            detail: 'Doğru cevap: yaşam',
            action: SizedBox(height: 48),
          ),
        ),
        dark: true,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('quiz-feedback-mascot')), findsNothing);
    });
  });

  group('çark: marka paleti, maskotlu göbek', () {
    test('siyah/gri dilim yok; rakamlar her dilimde ≥ 4,5:1', () {
      expect(spinWheelSegmentColors, hasLength(4));
      for (final c in spinWheelSegmentColors) {
        final hsl = HSLColor.fromColor(c);
        expect(hsl.saturation, greaterThan(0.5), reason: '$c gri');
        expect(hsl.lightness, greaterThan(0.45), reason: '$c koyu/siyah');
        expect(
          _contrast(SahneVayColors.wheelInk, c),
          greaterThanOrEqualTo(4.5),
          reason: '$c üstünde rakam',
        );
      }
      const t = SahneTokens.night;
      for (final banned in [t.s1, t.s2, t.s3, t.bg]) {
        expect(spinWheelSegmentColors, isNot(contains(banned)));
      }
    });

    for (final dark in [false, true]) {
      testWidgets('göbekte maskot, "ZK" yazısı yok (dark=$dark)', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          _shell(
            SpinWheelScreen(repository: MockZanKurdRepository()),
            dark: dark,
          ),
        );
        await tester.pump(const Duration(seconds: 1));
        expect(find.byKey(const ValueKey('spin-hub-mascot')), findsOneWidget);
        expect(find.text('ZK'), findsNothing);
        // Üst boşluk yok: günlük satır üst çubuğun hemen altındaki ilk
        // çeyrekte.
        final line = tester.getTopLeft(
          find.byKey(const ValueKey('spin-daily-line')),
        );
        expect(line.dy, lessThan(844 * 0.25));
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('eşleşme: oyun gibi kategori ızgarası', () {
    for (final dark in [false, true]) {
      testWidgets('doygun karolar 2 sütun; son karo alt düğmenin üstünde '
          '(dark=$dark)', (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          _shell(
            MatchmakingScreen(repository: MockZanKurdRepository()),
            dark: dark,
          ),
        );
        await tester.pumpAndSettle();
        final tiles = find.byType(SahnePickTile);
        expect(tiles, findsWidgets);
        expect(find.byType(SahneListRow), findsNothing, reason: 'liste döndü');
        final first = tester.getRect(tiles.at(0));
        final second = tester.getRect(tiles.at(1));
        expect(first.top, second.top, reason: 'iki sütun değil');
        expect(first.height, greaterThanOrEqualTo(SahnePickTile.minHeight));
        // Karo konu renginde DOYGUN (nötr yüzey değil).
        final t = SahneTokens.of(tester.element(tiles.first));
        final tile = tester.widget<SahnePickTile>(tiles.first);
        expect(tile.fill, isNot(t.s1));
        expect(
          _contrast(SahneVivid.onFill, tile.fill),
          greaterThanOrEqualTo(4.5),
        );

        final count = tiles.evaluate().length;
        await tester.drag(
          find.byType(CustomScrollView).first,
          const Offset(0, -4000),
        );
        await tester.pumpAndSettle();
        final last = find
            .byType(SahnePickTile)
            .at(find.byType(SahnePickTile).evaluate().length - 1);
        final cta = tester.getRect(
          find.byKey(const ValueKey('matchmaking-random-cta')),
        );
        expect(
          tester.getRect(last).bottom,
          lessThanOrEqualTo(cta.top),
          reason: 'son kategori düğmenin arkasında ($count karo)',
        );
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('320 pt ×2 Kurmancî: tek sütun, taşma yok', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _shell(
          MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 640),
              textScaler: TextScaler.linear(2),
            ),
            child: MatchmakingScreen(repository: MockZanKurdRepository()),
          ),
          ku: true,
        ),
      );
      await tester.pumpAndSettle();
      final tiles = find.byType(SahnePickTile);
      expect(tiles, findsWidgets);
      expect(tester.getRect(tiles.at(0)).width, greaterThan(250));
      expect(tester.takeException(), isNull);
    });

    testWidgets('bekleme sahnesi: altın VS rozeti + maskot, 72 px avatar', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _shell(
          MatchmakingScreen(
            loadRetryDelays: const [],
            repository: MockZanKurdRepository(),
          ),
          dark: true,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('matchmaking-random-cta')));
      await tester.pump();
      expect(find.byType(SahneVsBadge), findsOneWidget);
      expect(
        tester.getSize(find.byKey(const ValueKey('sahne-vs-badge'))),
        const Size(44, 44),
      );
      expect(find.byKey(const ValueKey('matchmaking-mascot-false')), findsOne);
      await tester.pumpWidget(_shell(const SizedBox()));
      await tester.pump(const Duration(seconds: 1));
    });
  });

  group('turnuva: eleme şeması', () {
    Future<void> pumpCup(
      WidgetTester tester, {
      Size size = const Size(390, 844),
      double textScale = 1,
      bool dark = false,
      bool ku = false,
    }) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = size;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        testShell(
          themeProvider: ThemeProvider(
            initialMode: dark ? ThemeMode.dark : ThemeMode.light,
          ),
          languageProvider: ku ? kurmanciLang() : turkishLang(),
          child: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
            child: Scaffold(
              body: TournamentScreen(repository: MockZanKurdRepository()),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 700));
    }

    testWidgets('turlar sütun sütun: 4 yuva → 2 yuva → taç, çizgiler', (
      tester,
    ) async {
      await pumpCup(tester);
      final bracket = find.byKey(const ValueKey('tournament-bracket-preview'));
      expect(bracket, findsOneWidget);
      await tester.ensureVisible(bracket);
      await tester.pump();
      expect(find.text('Yarı Final'), findsOneWidget);
      expect(find.text('Final'), findsOneWidget);
      expect(find.text('Şampiyon'), findsOneWidget);
      for (var j = 0; j < TournamentConfig.totalPlayers; j++) {
        expect(find.byKey(ValueKey('bracket-slot-0-$j')), findsOneWidget);
      }
      for (var j = 0; j < TournamentConfig.totalPlayers ~/ 2; j++) {
        expect(find.byKey(ValueKey('bracket-slot-1-$j')), findsOneWidget);
      }
      expect(find.byKey(const ValueKey('bracket-champion')), findsOneWidget);
      expect(find.byKey(const ValueKey('bracket-lines')), findsOneWidget);
      // Sütunlar soldan sağa: ilk tur < ikinci tur < şampiyon.
      final x0 = tester.getCenter(
        find.byKey(const ValueKey('bracket-slot-0-0')),
      );
      final x1 = tester.getCenter(
        find.byKey(const ValueKey('bracket-slot-1-0')),
      );
      final xc = tester.getCenter(
        find.byKey(const ValueKey('bracket-champion')),
      );
      expect(x0.dx, lessThan(x1.dx));
      expect(x1.dx, lessThan(xc.dx));
      // Ekran okuyucu bütün yolu tek cümlede duyar.
      expect(
        find.bySemanticsLabel(
          'Yarı Final · 4 oyuncu › Final · 2 oyuncu › Şampiyon',
        ),
        findsOneWidget,
      );
      // Eski sıkışık çip dizisi yok.
      expect(find.text('Yarı Final · 4 oyuncu'), findsNothing);
    });

    for (final dark in [false, true]) {
      testWidgets('320 pt ×2 (dark=$dark, KU): şema taşmaz', (tester) async {
        await pumpCup(
          tester,
          size: const Size(320, 640),
          textScale: 2,
          dark: dark,
          ku: true,
        );
        final bracket = find.byKey(
          const ValueKey('tournament-bracket-preview'),
        );
        await tester.ensureVisible(bracket);
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(find.byKey(const ValueKey('bracket-champion')), findsOneWidget);
      });
    }
  });

  group('sonuç: "Ayrıntılar" sahnenin cam yüzeyi', () {
    testWidgets('başlık nötr Perde değil, sahne camı', (tester) async {
      await pumpSahne(
        tester,
        _lang(
          const ResultCollapsibleSection(
            title: 'Ayrıntılar · 3 konu',
            summary: '',
            child: SizedBox(height: 40),
          ),
        ),
        dark: true,
        textScale: 1,
      );
      final header = find.byKey(const ValueKey('result-collapsible-header'));
      expect(header, findsOneWidget);
      expect(
        find.descendant(of: header, matching: find.byType(SahneSurfaceCard)),
        findsNothing,
      );
      final glass = tester.widget<Material>(
        find.byKey(const ValueKey('sahne-glass-card')),
      );
      expect(glass.color, SahneVivid.sheet);
      // Cam saydamdır: altındaki gece-mor sahnenin rengi geçer.
      expect(glass.color!.a, lessThan(0.2));
    });

    testWidgets('madalya kümesi tek odak: maskot madalyaya biner', (
      tester,
    ) async {
      await pumpSahne(
        tester,
        const Center(child: SahneMedalScene(stars: 3)),
        dark: true,
        size: const Size(390, 600),
        textScale: 1,
      );
      final medal = tester.getRect(find.byKey(const ValueKey('result-medal')));
      final mascot = tester.getRect(find.byType(ZanMascot));
      expect(mascot.overlaps(medal), isTrue, reason: 'iki ayrı odak');
      expect(mascot.width, lessThan(medal.width), reason: 'maskot baskın');
      // Madalya ekranın ortasında (puanla aynı eksen).
      expect((medal.center.dx - 195).abs(), lessThan(1));
      await tester.pump(const Duration(seconds: 1));
    });
  });

  group('kart kabartması: gri plaka yok, koyu temada canlı', () {
    test('dış gölge ≤ 2 px aşağı; gündüz kartın kendi renginden', () {
      expect(SahneEmbossStyle.outerShadow.offset.dy, lessThanOrEqualTo(2));
      const tint = Color(0xFFD6E9EC);
      final s = SahneEmbossStyle.shadowFor(tint: tint, night: false);
      expect(s.offset.dy, lessThanOrEqualTo(2));
      final hsl = HSLColor.fromColor(s.color.withValues(alpha: 1));
      expect(hsl.hue, closeTo(HSLColor.fromColor(tint).hue, 6));
    });

    for (final dark in [false, true]) {
      testWidgets('lobi kartı iki temada doygun gündüz rengi, filigran yok, '
          'gölge yok (dark=$dark)', (tester) async {
        await pumpSahne(
          tester,
          const SahneModeTile(
            lobby: true,
            icon: AppIcons.hourglass,
            title: 'Sırayla düello',
            subtitle: 'Sen oyna, rakip sonra',
            onTap: noop,
          ),
          dark: dark,
          size: const Size(200, 300),
          textScale: 1,
        );
        final ink = tester.widget<Ink>(
          find.byKey(const ValueKey('mode-tile-lobby')),
        );
        final g =
            (ink.decoration! as ShapeDecoration).gradient! as LinearGradient;
        expect(g.colors.first, SahneTokens.day.raceFill);
        expect(find.byKey(const ValueKey('sahne-icon-disc')), findsOneWidget);
        expect(
          tester.getSize(find.byKey(const ValueKey('sahne-icon-disc'))),
          const Size(68, 68),
        );
        expect(find.byKey(const ValueKey('sahne-tile-ridge')), findsOneWidget);
        // Filigran (büyük silik ikon) yok: ikon yalnız diskte.
        expect(find.byIcon(AppIcons.hourglass), findsOneWidget);
        final shell = tester.widget<SahneEmbossShell>(
          find.byType(SahneEmbossShell),
        );
        expect(shell.shadowColor!.a, 0);
      });
    }

    test('gece konu yüzeyi çamurlaşmaz: karışım ≤ %16, metin ≥ 4,5:1', () {
      const t = SahneTokens.night;
      for (final e in SahneCategoryTone.byCategory.entries) {
        final fill = e.value.fill(night: true);
        final surface = t.topicSurface(fill, night: true);
        expect(
          surface,
          Color.alphaBlend(fill.withValues(alpha: 0.14), t.s1),
          reason: e.key,
        );
        expect(_contrast(t.tx, surface), greaterThanOrEqualTo(4.5));
      }
    });
  });
}
