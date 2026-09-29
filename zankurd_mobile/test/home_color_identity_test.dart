/// Ana ekranın renk kimliği bekçisi.
///
/// ## Kusur
///
/// Sahibi ana ekranı "renksiz" buldu: kapılar yalnız %8-16'lık soluk bir
/// ton taşıyor, konu karoları beyaz zemin + ince kenarlıktan ibaretti.
///
/// ## Niçin sessiz kalırdı
///
/// Var olan testler yalnız ANAHTARLARI ve DAVRANIŞI doğruluyordu; hiçbiri
/// rengi ya da görseli ÖLÇMÜYORDU.
///
/// ## 2026-09-29 Şahnê:
///
/// 2026-09-27'deki doygun degrade kapılar ve kategori degradeli karolar
/// Şahnê'ye taşındı: renk yalnız ROL taşır. Kapılar tek liste grubunda iki
/// satırdır — öğrenme satırının ikon karosu Zimrût, yarışınki Boyax;
/// konu karoları mücevher karodur (`SahneJewelTile`: kendi çizimi, yoksa
/// kobalt radyal + kendi ikonu). Günün dersi kartında maskot yok (logo
/// işareti marka satırında). Bu dosya bu kimliğin GERÇEKTEN orada olduğunu
/// ölçer.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zankurd_mobile/src/config/category_visuals.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/providers/auth_provider.dart';
import 'package:zankurd_mobile/src/providers/theme_provider.dart';
import 'package:zankurd_mobile/src/screens/home/home_sections.dart';
import 'package:zankurd_mobile/src/screens/home/today_task_card.dart';
import 'package:zankurd_mobile/src/screens/home_screen.dart';
import 'package:zankurd_mobile/src/services/premium_service.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';
import 'package:zankurd_mobile/src/widgets/roj_mascot.dart';
import 'package:zankurd_mobile/src/widgets/sahne/sahne.dart';

import 'support/widget_test_helpers.dart' show freshMockRepository;

Widget _wrap(Widget child) => MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => LanguageProvider(initialLang: 'tr')),
    ChangeNotifierProvider(create: (_) => AuthProvider.test()),
    ChangeNotifierProvider(create: (_) => ThemeProvider()),
    ChangeNotifierProvider<PremiumService>(
      create: (_) => PremiumService.fallback(),
    ),
  ],
  child: MaterialApp(
    theme: AppTheme.light(),
    darkTheme: AppTheme.dark(),
    home: child,
  ),
);

Future<void> _pumpHome(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(390, 1800));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    _wrap(
      HomeScreen(
        repository: freshMockRepository(),
        onOpenLearning: () async {},
        onOpenPlay: () {},
      ),
    ),
  );
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  setUp(() {
    freshMockRepository();
  });

  testWidgets('kapılar rol taşır: öğrenme Zimrût, yarış Boyax; degrade yok', (
    tester,
  ) async {
    await _pumpHome(tester);
    for (final (key, role) in [
      ('home-door-learn', SahneRole.learn),
      ('home-door-play', SahneRole.race),
    ]) {
      final finder = find.byKey(ValueKey(key));
      expect(finder, findsOneWidget, reason: key);
      final tile = tester.widget<HomeDoorTile>(finder);
      expect(tile.role, role, reason: key);
      expect(
        find.descendant(of: finder, matching: find.byType(SahneListRow)),
        findsOneWidget,
        reason: '$key liste satırı olmalı',
      );
      expect(
        find.descendant(of: finder, matching: find.byType(Ink)),
        findsNothing,
        reason: '$key degrade dolgulu kart olmamalı',
      );
    }
  });

  testWidgets(
    'her görünür kategori mücevher karodur; kendi çizimi olanlar o çizimi, '
    'olmayanlar kendi ikonunu gösterir',
    (tester) async {
      await _pumpHome(tester);
      final repo = freshMockRepository();
      expect(repo.categories, contains('Sînema'));

      for (final category in repo.categories) {
        final finder = find.byKey(ValueKey('home-topic-$category'));
        expect(finder, findsOneWidget, reason: category);
        final tile = tester.widget<SahneJewelTile>(
          find.descendant(of: finder, matching: find.byType(SahneJewelTile)),
        );
        expect(tile.name, CategoryNames.localized(category, false));
        expect(tile.otherName, CategoryNames.localized(category, true));

        if (CategoryVisuals.hasOwnImage(category)) {
          var provider = tile.image;
          if (provider is ResizeImage) provider = provider.imageProvider;
          expect(provider, isA<AssetImage>(), reason: category);
          expect(
            (provider! as AssetImage).assetName,
            CategoryVisuals.imagePath(category),
            reason: '$category görseli category_visuals ile eşleşmeli',
          );
        } else {
          // Sînema, Çand'ın çay/kilim fotoğrafını ÖDÜNÇ alırdı; kimlik
          // karosunda bu yanlış konuyu anlatır. Çizimsiz karo + kendi ikonu.
          expect(tile.image, isNull, reason: category);
          expect(
            find.descendant(
              of: finder,
              matching: find.byIcon(CategoryVisuals.icon(category)),
            ),
            findsOneWidget,
            reason: '$category yerine kendi ikonunu çizmeli',
          );
        }
      }
    },
  );

  testWidgets('konuların hepsi ilk bakışta: 390 pt ekranda dört sütun', (
    tester,
  ) async {
    await _pumpHome(tester);
    final repo = freshMockRepository();
    final tops = <double>{
      for (final c in repo.categories)
        tester.getTopLeft(find.byKey(ValueKey('home-topic-$c'))).dy,
    };
    // 7 kategori → 4 + 3: iki satır.
    expect(tops.length, (repo.categories.length / 4).ceil());
  });

  testWidgets('günün dersi kartında maskot yok', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: TodayTaskCard(
            isKu: false,
            loading: false,
            onStart: () {},
            done: 4,
            total: 10,
          ),
        ),
      ),
    );
    expect(find.byType(RojMascot), findsNothing);
    expect(find.byType(SahneStageCard), findsOneWidget);
  });
}
