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
/// * Yarış merkezinde kahraman Boyax gradyanlı, oda standart kart.
/// * B aşaması (2026-10-20): [soru ekranı bandı 2026-10-28 K6+ ile KALDIRILDI,
///   sonuç sahnesi K7 ile nötr]; sıralamada ilk üç kaide Zêr/gümüş/bronz madalya tonunda, kendi
///   satırın Zêr tonlu; sosyal ekranlar (arkadaşlar) Nîl, yarış ekranları
///   (turnuva, yarışma, çark, eşleşme) Boyax, öğrenme Zimrût bandı; gece konu
///   dolguları gündüzden sönük değil; kazanılmayan sonuç yıldızı konturlu
///   değil, kapat düğmesi cam.
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
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/screens/contest_screen.dart';
import 'package:zankurd_mobile/src/screens/friends_screen.dart';
import 'package:zankurd_mobile/src/screens/shop_screen.dart';
import 'package:zankurd_mobile/src/screens/home_screen.dart';
import 'package:zankurd_mobile/src/screens/quiz_screen.dart';
import 'package:zankurd_mobile/src/screens/tournament_screen.dart';
import 'package:zankurd_mobile/src/screens/play_hub_screen.dart';
import 'package:zankurd_mobile/src/screens/quiz_result_screen.dart';
import 'package:zankurd_mobile/src/services/premium_service.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';
import 'package:zankurd_mobile/src/widgets/sahne/sahne.dart';
import 'package:zankurd_mobile/src/widgets/zk_back_button.dart';

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
      // 2026-10-28 kurul K1: "dolu karo" kararı (2026-10-20) geri alındı;
      // karo nötr yüzey, renk rozet + kenar şeridinde. Ayrıntılı bekçi:
      // `konu_karosu_notr_test.dart`; burada yalnız konu rengi eşlemesi.
      testWidgets(
        'ana sayfa karolarında konu rengi rozet+şeritte (dark=$dark)',
        (tester) async {
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
            final strip = tester.widget<ColoredBox>(
              find.byKey(ValueKey('home-topic-strip-$category')),
            );
            expect(
              strip.color,
              CategoryVisuals.tone(category).fill(night: dark),
              reason: '$category şeridi konu renginde olmalı',
            );
          }
        },
      );
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
      testWidgets('kahraman Boyax gradyanlı, oda standart kart '
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

        // 2026-10-28, kurul K3/K5: Oda artık DOLU Nîl blok değil, standart
        // kart yüzeyi (`t.s1`); Nîl rengi yalnız ikon rozetinde kalır
        // (ikincil kartlar ana eylemle yarışmasın). Hero Boyax gradyanı ve
        // tek turuncu düğme korunur — canlılık kaybı değil, amaçlı renk.
        final room = find.byKey(const ValueKey('play-hub-room'));
        expect(
          tester
              .widget<SahneTappable>(
                find.descendant(of: room, matching: find.byType(SahneTappable)),
              )
              .color,
          t.s1,
          reason: 'Oda kartı standart kart yüzeyinde olmalı (K5)',
        );
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
      testWidgets('sahne nötr (K7); çipler, Zêr kartı ve "Nerelerde '
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

        // K7 (2026-10-28) GEÇERSİZ KILDI: "sahne mod renginde (Boyax
        // gradyanı)" kararı. Sonuç ekranı NÖTR sahnedir; başarı vurgusu
        // altın/yeşil, kırmızı yalnız yanlış sayısında.
        expect(find.byKey(const ValueKey('sahne-stage-scene')), findsNothing);

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

  group('B aşaması: renk kalan ekranlara yayıldı', () {
    test(
      'gece konu dolgusu gündüzden sönük değil (doygunluk ve parlaklık)',
      () {
        for (final category in SahneCategoryTone.byCategory.keys) {
          final tone = CategoryVisuals.tone(category);
          final day = HSLColor.fromColor(tone.fill(night: false));
          final night = HSLColor.fromColor(tone.fill(night: true));
          expect(
            night.saturation,
            greaterThanOrEqualTo(day.saturation * 0.9),
            reason: '$category gece doygunluğu',
          );
          expect(
            night.lightness,
            greaterThanOrEqualTo(day.lightness - 0.06),
            reason: '$category gece parlaklığı',
          );
        }
      },
    );

    test('madalya tonları üstünde sıra rakamı ve ad >= 4.5:1', () {
      for (final t in [SahneTokens.day, SahneTokens.night]) {
        final rank = [t.goldTx, t.silverTx, t.bronzeTx];
        for (var place = 0; place < 3; place++) {
          final tint = t.medalTint(place);
          expect(_contrast(rank[place], tint), greaterThanOrEqualTo(4.5));
          expect(_contrast(t.tx, tint), greaterThanOrEqualTo(4.5));
        }
      }
    });

    test('Zimrût ve Nîl koyu uçlarında beyaz yazı >= 4.5:1', () {
      const white = Color(0xFFFFFFFF);
      for (final t in [SahneTokens.day, SahneTokens.night]) {
        expect(_contrast(white, t.learnDeep), greaterThanOrEqualTo(4.5));
        expect(_contrast(white, t.nilDeep), greaterThanOrEqualTo(4.5));
        expect(_contrast(white, t.nilFill), greaterThanOrEqualTo(4.5));
      }
    });

    // K6+ (2026-10-28) GEÇERSİZ KILDI: B aşamasının "üst band sorunun
    // konusunun renginde" kararı. Soru sahnesi her modda ve her konuda AYNI
    // nötr sahnedir (turkuaz/yeşil/mor bant yok); konu yalnız küçük
    // künyede. Bekçisi `soru_sonuc_ortak_sahne_test`.
    testWidgets('soru ekranında konu renkli üst bant yok', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repository = freshMockRepository();
      for (final category in ['Dîrok', 'Ziman']) {
        await tester.pumpWidget(
          testShell(
            child: QuizScreen(
              key: ValueKey(category),
              repository: repository,
              room: repository.createRoom(),
              questions: [
                QuizQuestion(
                  id: 'band-$category',
                  category: category,
                  prompt: 'Pirs',
                  answers: const ['A', 'B', 'C', 'D'],
                  correctAnswer: 'A',
                  explanation: 'Şirove',
                ),
              ],
              enableTimer: false,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('sahne-stage-band')),
          findsNothing,
          reason: '$category: konu bandı geri gelmiş',
        );
      }
    });

    for (final (name, role, build) in <(String, SahneRole, Widget Function())>[
      (
        'arkadaşlar',
        SahneRole.social,
        () => FriendsScreen(repository: MockZanKurdRepository()),
      ),
      (
        'turnuva',
        SahneRole.race,
        () => TournamentScreen(repository: MockZanKurdRepository()),
      ),
      (
        'yarışma',
        SahneRole.race,
        () => ContestScreen(repository: MockZanKurdRepository()),
      ),
    ]) {
      // 2026-10-28 kurul K2: üst çubuk nötr; rol rengi yalnız 3 px çizgi.
      testWidgets('$name çubuğu nötr, rol rengi yalnız ince çizgide', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(const Size(390, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(testShell(child: build()));
        await tester.pump(const Duration(seconds: 1));
        final line = tester.widget<ColoredBox>(
          find.descendant(
            of: find.byKey(ZkAccentLine.valueKey),
            matching: find.byType(ColoredBox),
          ),
        );
        expect(
          line.color,
          SahneTokens.of(
            tester.element(find.byKey(ZkAccentLine.valueKey)),
          ).roleFill(role),
        );
      });
    }
  });

  // C aşaması (2026-10-20): soru sahnesi konunun rengini taşır; tonal düğme
  // gece okunur.
  group('C aşaması', () {
    testWidgets('soru sahnesi zemininin üst rengi konu tonundan türer', (
      tester,
    ) async {
      for (final category in CategoryVisuals.colorDefinedCategories) {
        for (final night in [false, true]) {
          final fill = CategoryVisuals.tone(category).fill(night: night);
          await tester.pumpWidget(
            _wrap(
              SahneStageScaffold(band: fill, body: const SizedBox.expand()),
              dark: true,
            ),
          );
          final box = tester.widget<DecoratedBox>(
            find.byKey(const ValueKey('sahne-stage-band-floor')),
          );
          final g =
              (box.decoration as BoxDecoration).gradient! as LinearGradient;
          expect(
            g.colors.first,
            Color.lerp(fill, SahneStageColors.top, 0.55),
            reason: '$category koyu ton konudan türer',
          );
          // Zeminin en açık noktası üst uç: beyaz soru metni >= 4.5.
          expect(
            _contrast(const Color(0xFFFFFFFF), g.colors.first),
            greaterThanOrEqualTo(4.5),
            reason: '$category en açık nokta',
          );
        }
      }
    });

    test('tonal düğme gece etiketi beyaz dolguda >= 4.5:1', () {
      for (final (name, t) in [
        ('gündüz', SahneTokens.day),
        ('gece', SahneTokens.night),
      ]) {
        expect(
          _contrast(t.nilOnWhite, const Color(0xFFFFFFFF)),
          greaterThanOrEqualTo(4.5),
          reason: '$name Nîl beyaz tonal',
        );
      }
    });
  });
  // D aşaması (2026-10-20, kurul): mağaza Zêr kimliği, konu tonlu şıklar,
  // gece ikincil metin, cam davet düğmesi.
  group('D aşaması', () {
    for (final dark in [false, true]) {
      testWidgets(
        'mağaza üst çubuğu nötr + Zêr çizgisi, bakiye çipi koyu (${dark ? "gece" : "gündüz"})',
        (tester) async {
          await tester.pumpWidget(
            _wrap(ShopScreen(repository: MockZanKurdRepository()), dark: dark),
          );
          await tester.pump(const Duration(seconds: 1));
          final t = SahneTokens.of(tester.element(find.byType(ShopScreen)));
          final bar = tester.widget<AppBar>(find.byType(AppBar));
          expect(bar.backgroundColor, t.bg);
          expect(bar.bottom, isA<ZkAccentLine>());
          expect(_contrast(t.onZer, t.zerBand), greaterThanOrEqualTo(4.5));
          expect(
            _contrast(SahneVivid.onFill, t.zerChip),
            greaterThanOrEqualTo(4.5),
          );
        },
      );
    }

    test('şık dolgusu konu tonundan türer ve metin >= 4.5:1', () {
      for (final (name, t) in [
        ('gündüz', SahneTokens.day),
        ('gece', SahneTokens.night),
      ]) {
        for (final category in SahneCategoryTone.byCategory.keys) {
          final tone = CategoryVisuals.tone(category);
          final fill = t.optionFillFor(tone);
          expect(
            fill,
            Color.lerp(t.optionFill, tone.fill(night: name == 'gece'), 0.15),
            reason: '$name $category konudan türer',
          );
          expect(fill, isNot(t.optionFill), reason: '$category düz gri değil');
          expect(
            _contrast(t.tx, fill),
            greaterThanOrEqualTo(4.5),
            reason: '$name $category şık metni',
          );
        }
      }
    });

    test('gece tx3 sahne kartları üstünde >= 4.5:1', () {
      const t = SahneTokens.night;
      for (final (name, bg) in [
        ('bg', t.bg),
        ('s1', t.s1),
        ('s2', t.s2),
        ('optionFill', t.optionFill),
        ('race1', SahneStageColors.race1),
        ('goldTint', t.goldTint),
      ]) {
        expect(
          _contrast(t.tx3, bg),
          greaterThanOrEqualTo(4.5),
          reason: 'tx3 / $name',
        );
      }
      expect(
        _contrast(t.tx2, SahneStageColors.race1),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrast(t.heroCaptionTx, SahneStageColors.race1),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('davet ikinci düğmesi (cam) Nîl kartta beyaz yazı >= 4.5:1', () {
      for (final t in [SahneTokens.day, SahneTokens.night]) {
        for (final card in [t.nilFill, t.nilDeep]) {
          final glass = _over(SahneVivid.glassButton, card);
          expect(
            _contrast(SahneVivid.onFill, glass),
            greaterThanOrEqualTo(4.5),
          );
          expect(glass, isNot(card), reason: 'zeminden ayrışır');
        }
      }
      expect(SahneVivid.glassButtonEdge.a, greaterThan(0.5));
    });
  });
}
