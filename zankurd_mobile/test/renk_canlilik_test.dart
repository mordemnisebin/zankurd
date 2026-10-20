/// Renk ve canlılık bekçisi (2026-10-20).
///
/// ## Kusur
///
/// Sahibi son sürümü "renkliliği, canlılığı öldürüldü" diye tarif etti.
/// Sadeleştirme turları (2026-10-19/20) rengi tek turuncuya (Agir) indirmişti:
/// konu karoları beyaz kart + 28 px'lik koyu kısık ikon kutusu, yarış merkezi
/// beyaz kartlar ve çerçeveli gri düğmeler, sonuç ekranı düz grafit zemin
/// üstünde gri kartlardı. Kimlik renkleri (Zimrût, Boyax, konu ışıkları)
/// kodda duruyor ama ekranda yalnız aksan boyutundaydı.
///
/// ## Niçin sessiz kalırdı
///
/// Var olan testler anahtarları, davranışı ve (en fazla) bir rolün VAR
/// olduğunu ölçüyordu; bir karonun TAMAMEN konu renginde dolu olup olmadığını
/// ya da bir modun büyük bir yüzeyinin kendi renginde durup durmadığını hiçbiri
/// sormuyordu. Rengi sessizce griye çeviren bir sadeleştirme hiçbir testi
/// kırmazdı.
///
/// ## Bu dosya neyi korur
///
/// * Konu karoları DOLU konu renginde (gündüz/gece), üstündeki beyaz yazı
///   ≥ 4.5:1 (11 konunun hepsi, iki temada).
/// * Mod renkleri uygulanır: öğrenme Zimrût, yarış Boyax, sosyal Nîl; ton
///   zemin üstündeki mod metni ≥ 4.5:1.
/// * Yarış merkezinde kahraman Boyax gradyanlı, oda düğmeleri Nîl tonlu.
/// * Sonuç sahnesi mod renginde gradyandır; renkli Doğru/Yanlış/Üst üste
///   çipleri, Zêr "Kazanıldı" kartı VAR; "Nerelerde zorlandın?" bölümü
///   DURUR (maket kaldırmıştı; ürün kararıyla korunur).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/config/category_visuals.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/models/answer_record.dart';
import 'package:zankurd_mobile/src/providers/auth_provider.dart';
import 'package:zankurd_mobile/src/providers/sound_provider.dart';
import 'package:zankurd_mobile/src/providers/theme_provider.dart';
import 'package:zankurd_mobile/src/screens/home_screen.dart';
import 'package:zankurd_mobile/src/screens/play_hub_screen.dart';
import 'package:zankurd_mobile/src/screens/quiz_result_screen.dart';
import 'package:zankurd_mobile/src/services/premium_service.dart';
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

/// Yarı saydam rengi zemin üstünde karıştırır.
Color _over(Color fg, Color bg) => Color.alphaBlend(fg, bg);

Widget _wrap(Widget child, {required bool dark}) => MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => LanguageProvider(initialLang: 'tr')),
    ChangeNotifierProvider(create: (_) => AuthProvider.test()),
    ChangeNotifierProvider(create: (_) => ThemeProvider()),
    ChangeNotifierProvider<SoundProvider>(create: (_) => SoundProvider()),
    ChangeNotifierProvider<PremiumService>(
      create: (_) => PremiumService.fallback(),
    ),
  ],
  child: MaterialApp(
    theme: AppTheme.light(),
    darkTheme: AppTheme.dark(),
    themeMode: dark ? ThemeMode.dark : ThemeMode.light,
    home: child,
  ),
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('konu renkleri: karonun tamamı konunun rengidir', () {
    test('11 konunun beyaz yazısı iki temada da >= 4.5:1', () {
      const white = Color(0xFFFFFFFF);
      for (final category in SahneCategoryTone.byCategory.keys) {
        final tone = CategoryVisuals.tone(category);
        expect(tone.dayFill, isNotNull, reason: '$category gündüz dolgusu');
        expect(tone.nightFill, isNotNull, reason: '$category gece dolgusu');
        for (final night in [false, true]) {
          final fill = tone.fill(night: night);
          expect(
            _contrast(white, fill),
            greaterThanOrEqualTo(4.5),
            reason: '$category night=$night beyaz ad',
          );
          // Kurmancî ikinci satır: beyaz %92 zemin üstünde.
          expect(
            _contrast(_over(const Color(0xEBFFFFFF), fill), fill),
            greaterThanOrEqualTo(4.5),
            reason: '$category night=$night ikinci satır',
          );
        }
      }
    });

    test('gece dolgusu gündüz dolgusundan koyudur ama griye dönmez', () {
      for (final category in SahneCategoryTone.byCategory.keys) {
        final tone = CategoryVisuals.tone(category);
        final day = HSLColor.fromColor(tone.fill(night: false));
        final night = HSLColor.fromColor(tone.fill(night: true));
        expect(
          night.lightness,
          lessThanOrEqualTo(day.lightness + 0.001),
          reason: category,
        );
        expect(
          night.saturation,
          greaterThan(0.3),
          reason: '$category gece karosu gri leke olmamalı',
        );
      }
    });

    for (final dark in [false, true]) {
      testWidgets('ana sayfa karoları DOLU konu renginde (dark=$dark)', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(const Size(390, 2000));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final repo = freshMockRepository();
        await tester.pumpWidget(
          _wrap(
            HomeScreen(
              repository: repo,
              onOpenLearning: () async {},
              onOpenPlay: () {},
            ),
            dark: dark,
          ),
        );
        await tester.pump(const Duration(seconds: 1));
        for (final category in repo.categories) {
          final tile = find.byKey(ValueKey('home-topic-$category'));
          expect(tile, findsOneWidget, reason: category);
          final surface = tester.widget<SahneTappable>(
            find.descendant(of: tile, matching: find.byType(SahneTappable)),
          );
          expect(
            surface.color,
            CategoryVisuals.tone(category).fill(night: dark),
            reason: '$category karosu konu renginde dolu olmalı',
          );
          // Beyaz ad: renk beyaz, koyu konu metni değil.
          final name = tester.widget<Text>(
            find
                .descendant(
                  of: tile,
                  matching: find.text(CategoryNames.tile(category, false)),
                )
                .first,
          );
          expect(name.style?.color, const Color(0xFFFFFFFF), reason: category);
        }
      });
    }
  });

  group('mod renkleri belirteçtir ve okunur', () {
    test('Zimrût, Boyax, Nîl dolguları maketteki değerlerdedir', () {
      expect(SahneTokens.day.learnFill, const Color(0xFF0E8360));
      expect(SahneTokens.day.raceFill, const Color(0xFFC2304F));
      expect(SahneTokens.day.nilFill, const Color(0xFF3E5BD6));
      expect(SahneTokens.day.learnTint, const Color(0xFFE3F5EE));
      expect(SahneTokens.day.raceTint, const Color(0xFFFBE6EB));
      expect(SahneTokens.day.nilTint, const Color(0xFFE7ECFC));
      expect(SahneTokens.night.learnFill, const Color(0xFF1F7A5C));
      expect(SahneTokens.night.raceFill, const Color(0xFF8E2A45));
      expect(SahneTokens.night.raceDeep, const Color(0xFF43202F));
      expect(SahneTokens.night.nilFill, const Color(0xFF2E3F8F));
    });

    test('mod metni ton zemini üstünde >= 4.5:1 (iki tema)', () {
      for (final (name, t) in [
        ('gündüz', SahneTokens.day),
        ('gece', SahneTokens.night),
      ]) {
        expect(
          _contrast(t.learnTx, t.learnTint),
          greaterThanOrEqualTo(4.5),
          reason: '$name Zimrût',
        );
        expect(
          _contrast(t.raceTx, t.raceTint),
          greaterThanOrEqualTo(4.5),
          reason: '$name Boyax',
        );
        expect(
          _contrast(t.nilTx, t.nilTint),
          greaterThanOrEqualTo(4.5),
          reason: '$name Nîl',
        );
      }
    });

    test('dolu mod yüzeyinde beyaz yazı >= 4.5:1', () {
      const white = Color(0xFFFFFFFF);
      for (final t in [SahneTokens.day, SahneTokens.night]) {
        expect(_contrast(white, t.learnFill), greaterThanOrEqualTo(4.5));
        expect(_contrast(white, t.raceFill), greaterThanOrEqualTo(4.5));
        expect(_contrast(white, t.nilFill), greaterThanOrEqualTo(4.5));
      }
    });
  });

  group('yarış merkezi', () {
    for (final dark in [false, true]) {
      testWidgets('kahraman Boyax gradyanlı, oda düğmeleri Nîl tonlu '
          '(dark=$dark)', (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 1000));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          _wrap(PlayHubScreen(repository: MockZanKurdRepository()), dark: dark),
        );
        await tester.pumpAndSettle();
        final t = dark ? SahneTokens.night : SahneTokens.day;

        final hero = find.byKey(const ValueKey('play-hub-quick-duel'));
        final gradient = tester
            .widgetList<DecoratedBox>(
              find.descendant(of: hero, matching: find.byType(DecoratedBox)),
            )
            .map((d) => d.decoration)
            .whereType<BoxDecoration>()
            .map((d) => d.gradient)
            .whereType<LinearGradient>()
            .first;
        expect(gradient.colors, [t.raceFill, t.raceDeep]);

        for (final key in ['play-hub-create-room', 'play-hub-join-room']) {
          final button = tester.widget<FilledButton>(
            find.descendant(
              of: find.byKey(ValueKey(key)),
              matching: find.byType(FilledButton),
            ),
          );
          expect(
            button.style?.backgroundColor?.resolve(<WidgetState>{}),
            t.nilTint,
            reason: '$key Nîl tonlu olmalı',
          );
        }
      });
    }
  });

  group('sonuç ekranı', () {
    AnswerRecord record(String id, String category, {required bool correct}) =>
        AnswerRecord(
          id: id,
          category: category,
          prompt: 'Pirs $id',
          answers: const ['A', 'B'],
          correctAnswer: 'A',
          selectedAnswer: correct ? 'A' : 'B',
          explanation: 'Şirove',
        );

    for (final dark in [false, true]) {
      testWidgets('sahne mod renginde; çipler, Zêr kartı ve "Nerelerde '
          'zorlandın?" durur (dark=$dark)', (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 1800));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final repository = MockZanKurdRepository();
        await tester.pumpWidget(
          _wrap(
            QuizResultScreen(
              repository: repository,
              room: repository.createRoom(),
              score: 240,
              correctCount: 2,
              wrongCount: 1,
              totalQuestions: 3,
              bestStreak: 2,
              coinsAwarded: 30,
              answerRecords: [
                record('d1', 'Ziman', correct: true),
                record('d2', 'Ziman', correct: true),
                record('t1', 'Dîrok', correct: false),
              ],
            ),
            dark: dark,
          ),
        );
        await tester.pump(const Duration(seconds: 2));

        // Zemin: düz grafit değil, Boyax'tan koyuya gradyan.
        final scene = tester.widget<DecoratedBox>(
          find.byKey(const ValueKey('sahne-stage-scene')),
        );
        final colors =
            ((scene.decoration as BoxDecoration).gradient! as LinearGradient)
                .colors;
        expect(
          colors.first,
          dark ? const Color(0xFF6B2A45) : const Color(0xFFB8294A),
        );
        expect(colors.length, 4);

        // Renkli Doğru / Yanlış / Üst üste çipleri.
        final chips = tester.widgetList<DecoratedBox>(
          find.descendant(
            of: find.byType(ResultStatTiles),
            matching: find.byType(DecoratedBox),
          ),
        );
        expect(
          chips.where((d) {
            final dec = d.decoration;
            return dec is ShapeDecoration &&
                dec.color != null &&
                dec.color!.a > 0 &&
                dec.color!.a < 0.5;
          }).length,
          greaterThanOrEqualTo(3),
          reason: 'çipler ton dolgulu olmalı',
        );

        // Zêr "Kazanıldı" kartı: altın tonlu zemin.
        final reward = find.ancestor(
          of: find.text('Kazanıldı'),
          matching: find.byType(SahneTappable),
        );
        expect(reward, findsOneWidget);
        final rewardColor = tester.widget<SahneTappable>(reward).color;
        expect(rewardColor.a, lessThan(0.5));
        expect(rewardColor.r, greaterThan(rewardColor.b));

        // Maket "Nerelerde zorlandın" bölümünü çıkarmıştı; ürün kararıyla
        // DURUR.
        expect(find.text('Nerelerde zorlandın?'), findsOneWidget);
      });
    }
  });
}
