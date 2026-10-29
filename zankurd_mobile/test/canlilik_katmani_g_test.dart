// 2026-10-29 canlılık katmanı (G1–G4) bekçisi.
//
// Kusur: rakiplerle (TRT Bil Bakalım, QuizPlanet, Trivia Crack) yan yana
// konunca uygulama düzenli ama soluk ve düzdü: oyun sahneleri düz neredeyse
// siyah (#121214), Yarış sekmesinin ikincil mod kartları pastel, konu
// tonları silikti. Sahip "rakipler kadar canlı, ama eski gökkuşağı
// kargaşasına dönmeden" istedi.
//
// Niçin sessiz kalırdı: renk ve zemin hata vermez; eski testler "sahne
// var, metin okunur" derdi, zeminin DÜZ mü degrade mi olduğunu hiç
// ölçmezdi. Biri sahneyi yine düz griye çevirse hiçbir test kırılmazdı.
//
// Bu dosya şunları sabitler:
// * G1: soru, sonuç ve çark sahnesi gece-dağları degradesini çizer
//   (`SahneNightStage`), düz Şev (#121214) DEĞİL; iki temada aynı; en açık
//   durakta bile metin ≥ 4,5:1; şık dolgusu ve kenarı sahneden ayrışır.
// * G2: Yarış sekmesinde Sırayla düello ve Oda doygun "lobi" kartlarıdır
//   (kendi renklerinde degrade, beyaz yazı ≥ 4,5:1) ve ekranda TAM BİR
//   turuncu birincil düğme vardır (kahramandaki "Rakip bul").
// * G3: konu tonu açık %18 / koyu %26; ad ve ikinci satır ≥ 4,5:1
//   (ayrıntılı ölçüm `konu_tonu_kontrast_test.dart`).
//   2026-10-29 vay 2A: gece karışımı %26 → %14 (Astra: "koyu temada konu
//   kartları çamurlu"); kural `vay_2a_test` ile aynı formülü ölçer.
// * G2 (2026-10-29 vay 2A): lobi kartları İKİ temada da rolün DOYGUN
//   GÜNDÜZ rengindedir; gece belirteçleri koyu zeminde "kirli" okunuyordu.
// * G4: manzara şeridi paletleri doygunlaştı (gündüz gökyüzü belirgin mavi).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/providers/reduced_motion_provider.dart';
import 'package:zankurd_mobile/src/providers/remote_availability.dart';
import 'package:zankurd_mobile/src/providers/sound_provider.dart';
import 'package:zankurd_mobile/src/providers/theme_provider.dart';
import 'package:zankurd_mobile/src/screens/play_hub_screen.dart';
import 'package:zankurd_mobile/src/screens/quiz_screen.dart';
import 'package:zankurd_mobile/src/screens/spin_wheel_screen.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';
import 'package:zankurd_mobile/src/widgets/sahne/sahne.dart';

import 'support/widget_test_helpers.dart';

double _contrast(Color a, Color b) {
  final x = a.computeLuminance();
  final y = b.computeLuminance();
  final hi = x > y ? x : y;
  final lo = x > y ? y : x;
  return (hi + 0.05) / (lo + 0.05);
}

Widget _wrap(Widget child, {required bool dark}) => MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => LanguageProvider()..setLang('tr')),
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

void _expectNightStage(WidgetTester tester, String why) {
  final stage = find.byKey(const ValueKey('sahne-night-stage'));
  expect(stage, findsOneWidget, reason: '$why: gece dağları zemini yok');
  final paint = tester.widget<CustomPaint>(stage);
  expect(paint.painter, isA<SahneNightStagePainter>(), reason: why);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('G1 gece dağları zemini', () {
    test('degrade lacivert → mor; düz Şev (#121214) değil', () {
      const stops = [
        SahneStageColors.nightTop,
        SahneStageColors.nightMid,
        SahneStageColors.nightLow,
      ];
      for (final c in stops) {
        expect(c, isNot(AppTheme.bg));
      }
      // Düz değil: durakların parlaklığı yukarıdan aşağı artar.
      expect(
        stops[0].computeLuminance(),
        lessThan(stops[1].computeLuminance()),
      );
      expect(
        stops[1].computeLuminance(),
        lessThan(stops[2].computeLuminance()),
      );
      // Mavi/mor baskın (gri değil): her durakta mavi kanal kırmızıdan büyük
      // ya da eşit ve renk doygun.
      for (final c in stops) {
        final hsl = HSLColor.fromColor(c);
        expect(hsl.saturation, greaterThan(0.3), reason: '$c soluk');
      }
    });

    test('metin ve şık kontrastı: en açık durakta bile >= 4,5:1', () {
      const t = SahneTokens.night;
      for (final c in [
        SahneStageColors.nightTop,
        SahneStageColors.nightMid,
        SahneStageColors.nightLow,
        SahneStageColors.nightGround,
      ]) {
        expect(_contrast(t.tx, c), greaterThanOrEqualTo(4.5));
        expect(_contrast(t.tx2, c), greaterThanOrEqualTo(4.5));
      }
      expect(_contrast(t.tx, t.optionFill), greaterThanOrEqualTo(7));
      // Şık kenarı hem dolgudan hem sahneden ayrışır.
      expect(
        _contrast(t.optionEdge, SahneStageColors.nightMid),
        greaterThanOrEqualTo(3),
      );
      expect(
        _contrast(t.optionFill, SahneStageColors.nightMid),
        greaterThan(1.15),
        reason: 'şık dolgusu sahneden açık olmalı',
      );
    });

    for (final dark in [false, true]) {
      testWidgets('soru sahnesi degrade çizer (dark=$dark)', (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final repository = MockZanKurdRepository();
        await tester.pumpWidget(
          _wrap(
            QuizScreen(
              repository: repository,
              room: repository.createRoom(),
              questions: [repository.questions.first],
              enableTimer: false,
            ),
            dark: dark,
          ),
        );
        await tester.pumpAndSettle();
        _expectNightStage(tester, 'soru dark=$dark');
        final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
        expect(scaffold.backgroundColor, SahneStageColors.nightGround);
        expect(scaffold.backgroundColor, isNot(AppTheme.bg));
      });

      testWidgets('sonuç sahnesi degrade çizer (dark=$dark)', (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 1200));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          _wrap(
            SahneResultScaffold(
              neutral: true,
              hero: const SizedBox(height: 80),
              primary: SahneResultAction(label: 'Tamam', onPressed: () {}),
            ),
            dark: dark,
          ),
        );
        await tester.pump(const Duration(seconds: 1));
        _expectNightStage(tester, 'sonuç dark=$dark');
      });

      testWidgets('çark sahnesi degrade çizer (dark=$dark)', (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          _wrap(
            SpinWheelScreen(repository: MockZanKurdRepository()),
            dark: dark,
          ),
        );
        await tester.pump();
        await tester.pump();
        _expectNightStage(tester, 'çark dark=$dark');
      });
    }
  });

  group('G2 Yarış sekmesi oyun lobisi', () {
    for (final dark in [false, true]) {
      testWidgets('ikincil mod kartları doygun, tek turuncu birincil '
          '(dark=$dark)', (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 1400));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          KeyedSubtree(
            key: ValueKey('g2-$dark'),
            child: testShell(
              languageProvider: turkishLang(),
              themeProvider: ThemeProvider(
                initialMode: dark ? ThemeMode.dark : ThemeMode.light,
              ),
              remoteAvailability: RemoteAvailability(reachable: true),
              child: PlayHubScreen(
                repository: MockZanKurdRepository(),
                asyncDuelEnabled: true,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final t = dark ? SahneTokens.night : SahneTokens.day;
        const vivid = SahneTokens.day;
        for (final (key, fill) in [
          ('play-hub-async-duel', vivid.raceFill),
          ('play-hub-room', vivid.nilFill),
        ]) {
          final card = find.byKey(ValueKey(key));
          expect(card, findsOneWidget, reason: key);
          final lobby = find.descendant(
            of: card,
            matching: find.byKey(const ValueKey('mode-tile-lobby')),
          );
          expect(lobby, findsOneWidget, reason: '$key pastel, lobi değil');
          final deco = tester.widget<Ink>(lobby).decoration! as ShapeDecoration;
          final g = deco.gradient! as LinearGradient;
          expect(g.colors.first, fill, reason: '$key rolün doygun rengi');
          expect(
            HSLColor.fromColor(fill).saturation,
            greaterThan(0.4),
            reason: '$key doygun',
          );
          expect(
            _contrast(SahneVivid.onFill, g.colors.first),
            greaterThanOrEqualTo(4.5),
          );
          expect(
            _contrast(SahneVivid.onFill, g.colors.last),
            greaterThanOrEqualTo(4.5),
          );
          // Turuncu (Agir) dolgu değil.
          expect(g.colors.first, isNot(t.act));
        }
        // Ekranda TAM BİR Agir (turuncu) dolgulu yüzey: kahraman düğmesi.
        final orange = find.byWidgetPredicate((w) {
          if (w is DecoratedBox) {
            final d = w.decoration;
            if (d is ShapeDecoration && d.color == t.act) return true;
            if (d is BoxDecoration && d.color == t.act) return true;
          }
          return false;
        });
        expect(
          find.byKey(const ValueKey('play-hub-quick-duel-cta')),
          findsOneWidget,
        );
        expect(
          find.byType(Material).evaluate().where((e) {
            final m = e.widget as Material;
            return m.color == t.act;
          }).length,
          lessThanOrEqualTo(1),
          reason: 'birden çok turuncu Material yüzey',
        );
        expect(orange.evaluate().length, lessThanOrEqualTo(1));
      });
    }
  });

  group('G3 konu tonu', () {
    test('açık %18 / koyu %14 (vay 2A) ve ad metni >= 4,5:1', () {
      for (final night in [false, true]) {
        final t = night ? SahneTokens.night : SahneTokens.day;
        for (final e in SahneCategoryTone.byCategory.entries) {
          final fill = e.value.fill(night: night);
          expect(
            t.topicSurface(fill, night: night),
            Color.alphaBlend(fill.withValues(alpha: night ? 0.14 : 0.18), t.s1),
          );
          expect(
            _contrast(t.tx, t.topicSurface(fill, night: night)),
            greaterThanOrEqualTo(4.5),
            reason: '${e.key} night=$night',
          );
        }
      }
    });
  });

  group('G4 manzara paletleri doygun', () {
    test('gündüz göğü belirgin mavi, şafak turuncu, gece çivit', () {
      double sat(Color c) => HSLColor.fromColor(c).saturation;
      expect(sat(SahneVistaPalette.day.skyTop), greaterThan(0.8));
      expect(sat(SahneVistaPalette.dawn.skyTop), greaterThan(0.9));
      expect(sat(SahneVistaPalette.night.skyBottom), greaterThan(0.45));
      expect(sat(SahneVistaPalette.day.ridgeMid), greaterThan(0.7));
    });
  });
}
