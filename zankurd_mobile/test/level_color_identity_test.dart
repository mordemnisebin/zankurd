import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/config/category_visuals.dart';
import 'package:zankurd_mobile/src/data/level_progress_store.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/screens/level_screen.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';

/// Seviye ekranının renk kimliği bekçisi.
///
/// ## Kusur
///
/// Ana ekranın konu karoları `CategoryVisuals.gradient(category)` taşıyor,
/// alt kategori ekranının banner'ı kendi kategori görselini taşıyor — ama
/// alt kategoriden sonra açılan seviye ekranı hâlâ düz beyaz kart + sabit
/// `AppTheme.playGreen` ikonuydu. Kullanıcı "Dîrok"a girip madder tonunu
/// görüyor, alt kategoriyi seçip aynı tonu görüyor, seviyeye girince birden
/// HER kategoride aynı yeşili gördüğü nötr bir listeye düşüyordu — zincirin
/// son halkası kimliğini kaybediyordu. Sahibi uygulamayı "renksiz" buldu
/// (2026-09-27).
///
/// ## Niçin sessiz kalırdı
///
/// `level_screen_test.dart` anahtarları, kilit mantığını, semantics'i ve
/// davranışı doğruluyordu — hiçbiri RENGİ ölçmüyordu. Kart beyaz da olsa,
/// rozet gökkuşağı da olsa aynı testler yeşil kalırdı. Bu dosya üç şeyi
/// ölçer: rengin gerçekten kategori adına bağlı olduğunu (sabit yeşile
/// değil), kazanılmış (altın) / sıradaki (kategori rengi) / kilitli (nötr)
/// ayrımının karışmadığını, ve beyaz/aksan metnin her kategori tonunda
/// okunur kaldığını (WCAG AA).
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

  // Hero'nun gradyanlı zemini: tek `Container` olarak beklenir, dıştaki
  // gölge kutusu bilerek `DecoratedBox` (gradyansız) olduğu için karışmaz.
  Finder heroGradientContainer() => find.byWidgetPredicate((widget) {
    if (widget is! Container) return false;
    final decoration = widget.decoration;
    return decoration is BoxDecoration && decoration.gradient != null;
  });

  // Bir seviye kartının rozeti: kartın anahtarlı `Container`ının İÇİNDEKİ
  // İLK `Container` — Row'un ilk çocuğu (bkz. subcategory_screen_test.dart
  // aynı `.first` deseni).
  BoxDecoration badgeDecoration(WidgetTester tester, int levelNumber) {
    final badge = tester.widget<Container>(
      find
          .descendant(
            of: find.byKey(ValueKey('level-card-$levelNumber')),
            matching: find.byType(Container),
          )
          .first,
    );
    return badge.decoration as BoxDecoration;
  }

  // Ölçülen iki kategori de playGreen'den FARKLI bir tondadır — testler bu
  // yüzden "kategori rengi" ile "eski sabit yeşil"i karıştırırsa yakalar.
  const categories = ['Ziman', 'Dîrok'];

  for (final category in categories) {
    for (final dark in [false, true]) {
      final combo = 'kategori=$category dark=$dark';
      final accent = CategoryVisuals.color(category);

      testWidgets('hero gradyanı kategoriye bağlı, başlık beyaz ($combo)', (
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

        final gradientFinder = heroGradientContainer();
        expect(gradientFinder, findsOneWidget, reason: combo);
        final decoration =
            tester.widget<Container>(gradientFinder).decoration
                as BoxDecoration;
        expect(
          (decoration.gradient! as LinearGradient).colors,
          CategoryVisuals.gradient(category).colors,
          reason: combo,
        );

        final title = CategoryNames.localized(category, false);
        final titleText = tester.widget<Text>(find.text(title));
        expect(titleText.style?.color, Colors.white, reason: combo);
      });

      testWidgets(
        'taze ilerlemede seviye 1 sıradaki rozeti kategori rengiyle dolu, '
        'kilitli rozetler ne aksanla ne altınla dolu ($combo)',
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

          final badge1 = badgeDecoration(tester, 1);
          expect(badge1.color, accent, reason: combo);
          // Eski sabit `AppTheme.playGreen` ile karışmadığını doğrudan
          // ölçer; iki seçilen kategori de o tondan farklıdır.
          expect(badge1.color, isNot(AppTheme.playGreen), reason: combo);

          for (final locked in [2, 3, 4, 5]) {
            final badge = badgeDecoration(tester, locked);
            expect(badge.color, isNot(accent), reason: '$combo seviye $locked');
            expect(
              badge.color,
              isNot(AppTheme.gold),
              reason: '$combo seviye $locked',
            );
          }
        },
      );

      testWidgets(
        'seviye 1 oynanınca rozeti altına döner, seviye 2 sıradaki olur '
        '($combo)',
        (tester) async {
          // Bekçi önce STORE'u okur (bkz. görev talimatı): aynı tekil
          // örneği ekranın kendi `_loadProgress`i de okuyacak.
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

          final badge1 = badgeDecoration(tester, 1);
          expect(badge1.color, AppTheme.gold, reason: combo);

          final badge2 = badgeDecoration(tester, 2);
          expect(badge2.color, accent, reason: combo);

          for (final locked in [3, 4, 5]) {
            final badge = badgeDecoration(tester, locked);
            expect(badge.color, isNot(accent), reason: '$combo seviye $locked');
            expect(
              badge.color,
              isNot(AppTheme.gold),
              reason: '$combo seviye $locked',
            );
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

  test('her tanımlı kategorinin gradyan İKİ UCUNDA da beyaz metin WCAG AA '
      '(4.5:1) geçer', () {
    // `colorDefinedCategories` üzerinden GİZLİ kategoriler de (Paradigma,
    // Siyaset, Teknolojî) dahil taranır: biri yeniden görünür yapılırsa
    // bekçi onu da görsün.
    for (final category in CategoryVisuals.colorDefinedCategories) {
      for (final stop in CategoryVisuals.gradientColors(category)) {
        expect(
          contrast(Colors.white, stop),
          greaterThanOrEqualTo(4.5),
          reason: '$category → $stop',
        );
      }
    }
  });

  test('her kategori aksanının onSolid metni WCAG AA (4.5:1) geçer', () {
    for (final category in CategoryVisuals.colorDefinedCategories) {
      final accent = CategoryVisuals.color(category);
      final onSolid = AppColors.onSolid(accent);
      expect(
        contrast(onSolid, accent),
        greaterThanOrEqualTo(4.5),
        reason: category,
      );
    }
  });

  test('altının (AppTheme.gold) onSolid metni WCAG AA (4.5:1) geçer', () {
    final onSolid = AppColors.onSolid(AppTheme.gold);
    expect(contrast(onSolid, AppTheme.gold), greaterThanOrEqualTo(4.5));
  });
}
