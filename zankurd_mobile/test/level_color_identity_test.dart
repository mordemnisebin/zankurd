import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/level_progress_store.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/screens/level_screen.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';
import 'package:zankurd_mobile/src/widgets/sahne/sahne.dart';

/// Seviye ekranının renk kimliği bekçisi.
///
/// ## Kusur
///
/// Alt kategoriden sonra açılan seviye ekranı düz beyaz kart + sabit yeşil
/// ikondu; zincirin son halkası kimliğini kaybediyordu. Sahibi uygulamayı
/// "renksiz" buldu (2026-09-27).
///
/// ## Niçin sessiz kalırdı
///
/// `level_screen_test.dart` anahtarları, kilit mantığını, semantics'i ve
/// davranışı doğruluyordu — hiçbiri RENGİ ölçmüyordu.
///
/// 2026-09-29 Şahnê: 2026-09-27 çözümü (kategori degradeli kimlik kartı,
/// kategori renkli rozet) palet dışı renk kullanıyordu ve kalktı. Renk artık
/// ROL taşır ve kategori adından bağımsızdır; kimliği sahne kartı ve rol
/// renkleri verir. Bu dosya üç şeyi ölçer: kazanılmış (Zêr tonu + yıldız) /
/// sıradaki (sahne kartı + Zimrût tonu + tek Agir düğme) / kilitli (Kulis +
/// kilit) ayrımının karışmadığını, bunun her kategoride aynı kaldığını ve
/// renk çiftlerinin iki temada WCAG AA geçtiğini.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    LevelProgressStore.resetInstance();
  });

  Widget wrap(Widget child, {required bool dark}) => MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => LanguageProvider()..setLang('tr')),
    ],
    child: MaterialApp(
      theme: dark ? AppTheme.dark() : AppTheme.light(),
      home: child,
    ),
  );

  // Bir seviye kartının rozeti: kartın içindeki İLK `DecoratedBox`
  // (satırın ilk çocuğu, 44'lük M karo).
  Color badgeColor(WidgetTester tester, int levelNumber) {
    final badge = tester.widget<DecoratedBox>(
      find
          .descendant(
            of: find.byKey(ValueKey('level-card-$levelNumber')),
            matching: find.byWidgetPredicate(
              (w) =>
                  w is DecoratedBox &&
                  w.decoration is ShapeDecoration &&
                  (w.decoration as ShapeDecoration).shape == SahneShape.m,
            ),
          )
          .first,
    );
    return (badge.decoration as ShapeDecoration).color!;
  }

  const categories = ['Ziman', 'Dîrok'];

  for (final category in categories) {
    for (final dark in [false, true]) {
      final combo = 'kategori=$category dark=$dark';
      final t = dark ? SahneTokens.night : SahneTokens.day;

      testWidgets('çubukta kategori adı; elle yazılmış degrade yok ($combo)', (
        tester,
      ) async {
        await tester.pumpWidget(
          wrap(
            LevelScreen(
              repository: MockZanKurdRepository(),
              category: category,
            ),
            dark: dark,
          ),
        );
        await tester.pumpAndSettle();

        final title = CategoryNames.localized(category, false);
        final inBar = find.descendant(
          of: find.byType(AppBar),
          matching: find.text(title),
        );
        expect(inBar, findsOneWidget, reason: combo);
        // 2026-09-30 izgara: başlık bantlıdır (kategori tonu, her temada
        // gece zemini); ad gece metniyle yazılır, temaya göre değişmez.
        expect(
          DefaultTextStyle.of(tester.element(inBar)).style.color,
          SahneTokens.night.tx,
          reason: combo,
        );
        final gradients = find.byWidgetPredicate((widget) {
          if (widget is! Container) return false;
          final decoration = widget.decoration;
          return decoration is BoxDecoration && decoration.gradient != null;
        });
        expect(gradients, findsNothing, reason: combo);
      });

      testWidgets(
        'taze ilerlemede seviye 1 sahne kartında Zimrût rozetli, kilitliler '
        'Kulis ($combo)',
        (tester) async {
          await tester.pumpWidget(
            wrap(
              LevelScreen(
                repository: MockZanKurdRepository(),
                category: category,
              ),
              dark: dark,
            ),
          );
          await tester.pumpAndSettle();

          expect(
            tester.widget(find.byKey(const ValueKey('level-card-1'))),
            isA<SahneStageCard>(),
            reason: combo,
          );
          // Sahne kartı her temada gece çizilir.
          expect(
            badgeColor(tester, 1),
            SahneTokens.night.learnTint,
            reason: combo,
          );
          for (final locked in [2, 3, 4, 5]) {
            expect(badgeColor(tester, locked), t.s2, reason: '$combo $locked');
          }
        },
      );

      testWidgets(
        'seviye 1 oynanınca rozeti Zêr tonu + yıldız olur, seviye 2 sıradaki '
        '($combo)',
        (tester) async {
          final store = await LevelProgressStore.load();
          await store.markPlayed(category, null, 1);

          await tester.pumpWidget(
            wrap(
              LevelScreen(
                repository: MockZanKurdRepository(),
                category: category,
              ),
              dark: dark,
            ),
          );
          await tester.pumpAndSettle();

          expect(badgeColor(tester, 1), t.goldTint, reason: combo);
          final star = tester.widget<SahneGlyph>(
            find.descendant(
              of: find.byKey(const ValueKey('level-card-1')),
              matching: find.byType(SahneGlyph),
            ),
          );
          expect(star.kind, SahneGlyphKind.star, reason: combo);
          expect(star.filled, isTrue, reason: combo);

          expect(
            tester.widget(find.byKey(const ValueKey('level-card-2'))),
            isA<SahneStageCard>(),
            reason: combo,
          );
          for (final locked in [3, 4, 5]) {
            expect(badgeColor(tester, locked), t.s2, reason: '$combo $locked');
          }
        },
      );
    }
  }

  testWidgets('390×844, %200 yazıda seviye ekranı overflow yapmaz', (
    tester,
  ) async {
    // 2026-09-27 renklendirmesi kart dolgusuna filigran + harmanlı zemin
    // ekledi; büyük yazı ratchet'i bunun taşma açmadığını doğrular (bkz.
    // large_text_overflow_test.dart'taki `expectNoOverflow` ile aynı desen).
    tester.view.devicePixelRatio = 3.0;
    tester.view.physicalSize = const Size(390, 844) * 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
        child: wrap(
          LevelScreen(repository: MockZanKurdRepository(), category: 'Dîrok'),
          dark: false,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));

    expect(tester.takeException(), isNull);
  });

  double contrast(Color a, Color b) {
    final l1 = a.computeLuminance();
    final l2 = b.computeLuminance();
    final hi = math.max(l1, l2);
    final lo = math.min(l1, l2);
    return (hi + 0.05) / (lo + 0.05);
  }

  test('seviye ekranının renk çiftleri iki temada WCAG AA (4.5:1) geçer', () {
    for (final (theme, t) in [
      ('gündüz', SahneTokens.day),
      ('gece', SahneTokens.night),
    ]) {
      for (final (name, fg, bg) in [
        ('satır adı / Perde', t.tx, t.s1),
        ('kilitli satır adı / Perde', t.tx2, t.s1),
        ('soru sayısı / Perde', t.tx2, t.s1),
        ('kilitli rozet ikonu / Kulis', t.tx2, t.s2),
        ('açık rozet numarası / Kulis', t.tx, t.s2),
        ('birincil düğme: onAct / Agir', t.onAct, t.act),
      ]) {
        expect(
          contrast(fg, bg),
          greaterThanOrEqualTo(4.5),
          reason: '$theme $name',
        );
      }
    }
    // Sahne kartı her temada gece: sıradaki seviyenin numarası ve adı.
    const n = SahneTokens.night;
    expect(contrast(n.learnTx, n.learnTint), greaterThanOrEqualTo(4.5));
    for (final bg in [SahneStageColors.top, SahneStageColors.bottom]) {
      expect(contrast(n.tx, bg), greaterThanOrEqualTo(4.5));
      expect(contrast(n.tx2, bg), greaterThanOrEqualTo(4.5));
    }
  });
}
