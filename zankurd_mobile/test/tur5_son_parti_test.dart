import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/data/placement_store.dart';
import 'package:zankurd_mobile/src/screens/learning_screen.dart';
import 'package:zankurd_mobile/src/theme/app_icons.dart';
import 'package:zankurd_mobile/src/utils/text_glue.dart';
import 'package:zankurd_mobile/src/widgets/lexicon_lookup.dart';
import 'package:zankurd_mobile/src/models/tournament.dart';
import 'package:zankurd_mobile/src/providers/remote_availability.dart';
import 'package:zankurd_mobile/src/providers/theme_provider.dart';
import 'package:zankurd_mobile/src/screens/home/daily_tour_card.dart';
import 'package:zankurd_mobile/src/screens/home/home_sections.dart';
import 'package:zankurd_mobile/src/screens/home/today_task_card.dart';
import 'package:zankurd_mobile/src/screens/home_screen.dart';
import 'package:zankurd_mobile/src/screens/play_hub_screen.dart';
import 'package:zankurd_mobile/src/screens/spin_wheel_screen.dart';
import 'package:zankurd_mobile/src/screens/tournament_screen.dart';
import 'package:zankurd_mobile/src/widgets/sahne/sahne.dart';

import 'support/widget_test_helpers.dart';

/// 2026-10-28 tur 5 (jüri 5 + gerçek cihaz gezintisi): küçük yüzeylerin
/// bekçileri. Büyük olanlar (sonuç, quiz) kendi dosyalarındadır:
/// `tur5_sonuc_quiz_test.dart`.
///
/// ## Kusurlar ve niçin sessizdi
///
/// * W4: "Turnuvaya katıl" kahraman kartının içindeydi, kaydırınca
///   kayboluyordu; kupa yolu çipleri "4 › 2 › 1" gibi adsız sayılardı.
/// * W9: turuncu yalnız eylem rengidir; ilerleme çubuğu ve 3. sıra turuncuydu.
///   Renk bekçileri düğmeleri sayıyordu, çubuğu ve kaideyi değil.
/// * W11: 11 konu çift sütunda tek bir karo yalnız bırakıyordu.
/// * W16: sunucuya ulaşılamıyorken çark "Yarın tekrar gel" diyordu (yalan),
///   ana sayfa Günün turuna (sunucu gerektirir) yöneltiyordu.
///
/// Hepsi görünür, çalışan yollarda oluyordu; hiçbir test o durumları
/// (çevrimdışı çark, uzun lobi kaydırması, çubuk rengi) kurmuyordu.

class _LobbyRepo extends MockZanKurdRepository {
  @override
  Future<TournamentBracket?> loadRealTournamentBracket() async => null;

  @override
  Future<TournamentBracket?> loadTournamentBracket() async => null;

  @override
  Future<List<TournamentStandings>> loadTournamentStandings({
    int limit = 16,
  }) async => const [];
}

double _lin(double c) =>
    c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();

double _lum(Color c) =>
    0.2126 * _lin(c.r) + 0.7152 * _lin(c.g) + 0.0722 * _lin(c.b);

double _contrast(Color a, Color b) {
  final la = _lum(a), lb = _lum(b);
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('W4 turnuva lobisi', () {
    testWidgets('"Turnuvaya katıl" altta sabit; kupa yolu çipleri adlı', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(390, 700);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        testShell(child: TournamentScreen(repository: _LobbyRepo())),
      );
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump(const Duration(milliseconds: 700));

      final cta = find.byKey(const ValueKey('tournament-primary-cta'));
      expect(cta, findsOneWidget);
      // Sabit: içerik kaydırılabilir alanın DIŞINDA (alt perde).
      expect(
        find.descendant(of: find.byType(CustomScrollView), matching: cta),
        findsNothing,
      );
      final before = tester.getRect(cta);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
      await tester.pump();
      expect(tester.getRect(cta), before, reason: 'kaydırınca yerinde durur');
      expect(before.bottom, greaterThan(600), reason: 'ekranın dibinde');

      // 2026-10-29 tur 6 Y7: sayı birimli.
      expect(find.text('Yarı Final · 4 oyuncu'), findsOneWidget);
      expect(find.text('Final · 2 oyuncu'), findsOneWidget);
      expect(find.text('Şampiyon'), findsOneWidget);
    });
  });

  group('W3 öğrenme okları', () {
    testWidgets('"Tüm dersler (+N)" satırında kilit değil ok var', (
      tester,
    ) async {
      PlacementStore.resetInstance();
      await tester.pumpWidget(
        testShell(child: LearningScreen(repository: MockZanKurdRepository())),
      );
      await tester.pumpAndSettle();
      final more = find.byKey(const ValueKey('learning-locked-more'));
      expect(more, findsOneWidget);
      expect(
        find.descendant(of: more, matching: find.byIcon(AppIcons.chevronRight)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: more, matching: find.byIcon(AppIcons.lock)),
        findsNothing,
        reason: 'satır dersleri AÇAR; kilit "dokunulamaz" okunuyordu',
      );
    });
  });

  group('W5 çark metni', () {
    testWidgets('"Her gün 1 ücretsiz çevirme"; satın alınan ek hak yazılır', (
      tester,
    ) async {
      await tester.pumpWidget(
        testShell(child: SpinWheelScreen(repository: _ExtraSpinRepo(2))),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      final line = tester.widget<Text>(
        find.byKey(const ValueKey('spin-daily-line')),
      );
      expect(line.data, 'Her gün 1 ücretsiz çevirme + 2 ek çevirme');
      expect(find.text('Her gün bir kez çevir.'), findsNothing);
    });

    testWidgets('ek hak yoksa yalnız ücretsiz satırı', (tester) async {
      await tester.pumpWidget(
        testShell(child: SpinWheelScreen(repository: _ExtraSpinRepo(0))),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('Her gün 1 ücretsiz çevirme'), findsOneWidget);
    });
  });

  group('W17 öksüz açılış tırnağı', () {
    test(
      'tırnak kelimeye yapışır: hiçbir genişlikte satır tırnakla bitmez',
      () {
        const raw =
            'Çay evine giriyorsun. Garson diyor ki: "Hoş geldin! Ne içersin?" '
            'Sen de "Bir çay lütfen" diyorsun.';
        final glued = glueOpeningQuotes(raw);
        expect(glued, contains('"\u2060H'));
        bool endsWithOrphan(String text, double width) {
          final painter = TextPainter(
            text: TextSpan(text: text, style: const TextStyle(fontSize: 18)),
            textDirection: TextDirection.ltr,
          )..layout(maxWidth: width);
          var orphan = false;
          for (final line in painter.computeLineMetrics()) {
            final y = line.baseline - line.ascent / 2;
            final end = painter
                .getLineBoundary(painter.getPositionForOffset(Offset(width, y)))
                .end;
            if (end > 0 && text[end - 1] == '"') orphan = true;
          }
          painter.dispose();
          return orphan;
        }

        for (var w = 120.0; w <= 400; w += 1) {
          expect(endsWithOrphan(glued, w), isFalse, reason: 'genişlik $w');
        }
      },
    );

    testWidgets('sözlük sözcüğünün önündeki açılış tırnağı aynı yer tutucuda', (
      tester,
    ) async {
      // Kusurun asıl kaynağı: sözlük sözcüğü WidgetSpan'dır; önündeki tırnak
      // ayrı metin parçası kalınca yer tutucunun kırılım fırsatı onu satır
      // sonunda öksüz bırakıyordu (Android gezinti and_41).
      await tester.pumpWidget(
        testShell(
          child: const Scaffold(
            body: LexiconText(
              'Tu dikevî çayxaneyê. Xizmetkar dibêje: "dûr e! '
              'Tu çi vedixwî?"',
              style: TextStyle(fontSize: 18),
            ),
          ),
        ),
      );
      final rich = tester.widget<RichText>(
        find
            .descendant(
              of: find.byType(LexiconText),
              matching: find.byType(RichText),
            )
            .first,
      );
      // Text.rich, verilen aralığı bir kök aralığa sarar.
      final children =
          ((rich.text as TextSpan).children!.first as TextSpan).children!;
      var widgetSpans = 0;
      for (var i = 0; i < children.length - 1; i++) {
        if (children[i + 1] is WidgetSpan) {
          widgetSpans++;
          final prev = children[i];
          if (prev is TextSpan && prev.text != null) {
            expect(
              prev.text!.endsWith('"'),
              isFalse,
              reason: 'tırnak yer tutucudan ayrı metinde kaldı: ${prev.text}',
            );
          }
        }
      }
      expect(widgetSpans, greaterThan(0), reason: 'sözlük sözcüğü beklenir');
    });

    test('kapanış tırnağı ve boşluklu tırnak değişmez', () {
      expect(
        glueOpeningQuotes('dedi: "evet" ve "hayır"'),
        contains('"\u2060e'),
      );
      expect(glueOpeningQuotes('a " b'), 'a " b');
    });
  });

  group('W9 turuncu yalnız eylem', () {
    Future<Color> barFill(WidgetTester tester, ThemeMode mode) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        testShell(
          themeProvider: ThemeProvider(initialMode: mode),
          child: const Scaffold(
            body: SahneProgressBar(value: 0.5, tone: SahneProgressTone.action),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      final fills = find.descendant(
        of: find.byType(FractionallySizedBox),
        matching: find.byType(DecoratedBox),
      );
      final deco =
          tester.widget<DecoratedBox>(fills.first).decoration
              as ShapeDecoration;
      return deco.color!;
    }

    testWidgets('akış çubuğu: gündüz Öğren yeşili, gece beyaz; turuncu değil', (
      tester,
    ) async {
      final light = await barFill(tester, ThemeMode.light);
      expect(light, SahneTokens.day.learnBar);
      expect(light, isNot(SahneTokens.day.act));
      final dark = await barFill(tester, ThemeMode.dark);
      expect(dark, isNot(SahneTokens.night.act));
      expect(dark, SahneTokens.night.tx);
    });

    test('3. sıra bakır: turuncu eylem rengine yakın değil, metin ≥ 4,5:1', () {
      for (final t in [SahneTokens.day, SahneTokens.night]) {
        final bar = t.medalBar(2);
        expect(bar, const Color(0xFFA9713F));
        expect(
          _contrast(bar, t.act) < 1.6,
          isFalse,
          reason: 'bakır, turuncu eylemle karışmaz',
        );
        expect(
          _contrast(t.bronzeTx, t.medalTint(2)),
          greaterThanOrEqualTo(4.5),
          reason: '3. sıra yazısı kaide zemininde okunur',
        );
      }
    });
  });

  group('W11 ana sayfa konu ızgarası', () {
    testWidgets('12 karo; "Karışık" karışık alıştırmayı başlatır', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(390, 1600);
      addTearDown(tester.view.reset);
      var mixed = 0;
      final repo = MockZanKurdRepository();
      await tester.pumpWidget(
        testShell(
          child: Scaffold(
            body: SingleChildScrollView(
              child: HomeTopicGrid(
                isKu: false,
                categories: repo.categories,
                progress: const {},
                onOpen: (_) {},
                onMixed: () => mixed++,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      final tiles = find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey<String> &&
            (w.key! as ValueKey<String>).value.startsWith('home-topic-') &&
            !(w.key! as ValueKey<String>).value.startsWith('home-topic-mark') &&
            !(w.key! as ValueKey<String>).value.startsWith(
              'home-topic-strip',
            ) &&
            !(w.key! as ValueKey<String>).value.startsWith(
              'home-topic-badge',
            ) &&
            !(w.key! as ValueKey<String>).value.startsWith(
              'home-topic-progress',
            ) &&
            w.runtimeType.toString() == '_HomeTopicTile',
      );
      expect(tiles, findsNWidgets(repo.categories.length + 1));
      expect(repo.categories.length + 1, 12);
      expect(find.text('Karışık'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('home-topic-mixed')));
      expect(mixed, 1);
    });
  });

  group('W16 çevrimdışı', () {
    testWidgets('çark: "Yarın tekrar gel" değil, bağlantı mesajı', (
      tester,
    ) async {
      await tester.pumpWidget(
        testShell(
          remoteAvailability: RemoteAvailability(reachable: false),
          child: SpinWheelScreen(repository: _NoSpinRepo()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('Yarın tekrar gel.'), findsNothing);
      expect(find.text('İnternet bağlantısı gerekli'), findsOneWidget);
    });

    testWidgets('çark: gerçekten bugün çevrildiyse "Yarın tekrar gel" kalır', (
      tester,
    ) async {
      await tester.pumpWidget(
        testShell(child: SpinWheelScreen(repository: _NoSpinRepo())),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('Yarın tekrar gel.'), findsOneWidget);
    });

    Future<void> pumpHome(WidgetTester tester, {required bool offline}) async {
      final repo = freshMockRepository();
      SharedPreferences.setMockInitialValues({
        'zankurd.achievements.unlocked': ['first_game'],
      });
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(390, 1400);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        testShell(
          remoteAvailability: RemoteAvailability(reachable: !offline),
          child: HomeScreen(
            repository: repo,
            scrollController: ScrollController(),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
    }

    testWidgets(
      'ana sayfa: çevrimiçi Günün turu, çevrimdışı oynanabilir görev',
      (tester) async {
        await pumpHome(tester, offline: false);
        expect(find.byType(DailyTourCard), findsOneWidget);
        expect(find.byType(TodayTaskCard), findsNothing);

        await pumpHome(tester, offline: true);
        await tester.pump(const Duration(seconds: 1));
        expect(
          find.byType(DailyTourCard),
          findsNothing,
          reason: 'Günün turu sunucu ister; çevrimdışı görev yerel dersi açar',
        );
        expect(find.byType(TodayTaskCard), findsOneWidget);
      },
    );

    testWidgets(
      'W11: görev kartı ilerleme çubuğunu ilk doğrudan sonra gösterir',
      (tester) async {
        Future<void> pumpCard(int done) async {
          await tester.pumpWidget(
            testShell(
              child: Scaffold(
                body: SingleChildScrollView(
                  child: TodayTaskCard(
                    isKu: false,
                    loading: false,
                    onStart: () {},
                    done: done,
                    total: 10,
                  ),
                ),
              ),
            ),
          );
          await tester.pump();
        }

        await pumpCard(0);
        expect(
          find.byKey(const ValueKey('home-daily-task-progress')),
          findsNothing,
        );
        await pumpCard(3);
        expect(
          find.byKey(const ValueKey('home-daily-task-progress')),
          findsOneWidget,
        );
      },
    );

    testWidgets('Yarış: kilitli girişlere dokunmak net bağlantı mesajı verir', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(390, 1400);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        testShell(
          remoteAvailability: RemoteAvailability(reachable: false),
          child: Scaffold(
            body: PlayHubScreen(repository: MockZanKurdRepository()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final key in [
        'play-hub-daily-contest',
        'play-hub-tournament',
        'play-hub-room',
        'play-hub-quick-duel-cta',
      ]) {
        final target = find.byKey(ValueKey(key));
        expect(target, findsOneWidget, reason: key);
        await tester.ensureVisible(target);
        await tester.pump();
        await tester.tap(target, warnIfMissed: false);
        await tester.pump();
        expect(
          find.text('İnternet bağlantısı gerekli'),
          findsOneWidget,
          reason: '$key dokunuşu geri bildirimsiz kalmamalı',
        );
        ScaffoldMessenger.of(
          tester.element(find.byType(PlayHubScreen)),
        ).clearSnackBars();
        await tester.pump();
      }
    });
  });
}

class _ExtraSpinRepo extends MockZanKurdRepository {
  _ExtraSpinRepo(this.extra);

  final int extra;

  @override
  Future<bool> canSpinToday() async => true;

  @override
  Future<int> unusedExtraSpins() async => extra;
}

class _NoSpinRepo extends MockZanKurdRepository {
  @override
  Future<bool> canSpinToday() async => false;
}
