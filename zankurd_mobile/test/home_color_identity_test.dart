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
///
/// 2026-09-29 doğallık: konu karoları artık çizimsiz (K1). Bu bekçi eskiden
/// kendi çizimi olan kategorinin o çizimi gösterdiğini sabitliyordu; şimdi
/// her karonun çizimsiz olduğunu, kendi ikonunu ve kendi kategori tonunu
/// taşıdığını ölçer.
///
/// 2026-09-30 kimlik: karolarda ikonun yerini konunun K3 silüeti aldı
/// (`CategoryVisuals.mark`); silüeti olmayan konu eski ikonda kalır. Bekçi
/// "ikon çizilir" beklentisini "silüet çizilir, silüetsizde ikon çizilir"e
/// çevirdi.
///
/// 2026-09-30 simülatör: "dört sütun" bekçisi gerçek yazı tipiyle koşar
/// (ızgara sütun sayısını yazı genişliğinden çıkarır); davranış aynı.
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

import 'support/realistic_device.dart';
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
  // 2026-09-30 simülatör: konu ızgarası sütun sayısını yazının gerçek
  // genişliğinden çıkarır (büyük yazıda 4 sütun adları bölüyordu). Ölçü
  // fontunda her harf kare olduğundan "245 soru" 96 px tutar ve ızgara
  // 4 yerine 2 sütuna iner; "dört sütun" beklentisi ancak gerçek yazı
  // tipiyle anlamlıdır.
  setUpAll(loadAppFonts);

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
    'her görünür kategori çizimsiz mücevher karodur: kendi ikonu, kendi tonu',
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
        // Karoda KISA ad yazılır (Bilim ve Düşünce -> Bilim).
        expect(tile.name, CategoryNames.tile(category, false));
        // İki ad aynıysa (Siyaset) ikinci satırın SÖZÜ yazılmaz (satırın yeri
        // ayrılır): aynı sözü iki kez yazmak gürültü olur
        // (`_HomeTopicTile`: `other == name ? null`).
        final other = CategoryNames.tile(category, true);
        expect(
          tile.otherName,
          other == tile.name ? isNull : other,
          reason: category,
        );

        // Üretilmiş kategori çizimleri ızgarada yok; konu adı, ikonu ve
        // kendi renk ailesiyle ayrılır.
        expect(tile.image, isNull, reason: category);
        expect(tile.tone, CategoryVisuals.tone(category), reason: category);
        // 2026-09-30 kimlik: silüeti olan konu ikon yerine K3 silüetini
        // çizer. Görünür her konunun silüeti var (Siyaset, Paradigma ve
        // Teknolojî de; eskiden ikonda kalıyorlardı, yan yana tutarsızdı).
        // İkon dalı yalnız işaretsiz (bilinmeyen) kategori için durur.
        final mark = CategoryVisuals.mark(category);
        expect(mark, isNotNull, reason: '$category: silüetsiz karo kalmamalı');
        expect(tile.mark, mark, reason: category);
        final glyphs = find.descendant(
          of: finder,
          matching: find.byWidgetPredicate(
            (w) => w is CustomPaint && w.painter is SahneCategoryGlyphPainter,
          ),
        );
        final icon = find.descendant(
          of: finder,
          matching: find.byIcon(CategoryVisuals.icon(category)),
        );
        if (mark == null) {
          expect(glyphs, findsNothing, reason: category);
          expect(icon, findsOneWidget, reason: '$category ikonda kalmalı');
        } else {
          expect(glyphs, findsOneWidget, reason: '$category silüeti çizmeli');
          expect(icon, findsNothing, reason: '$category ikon çizmemeli');
        }
      }
    },
  );

  testWidgets(
    'konu ızgarası 390 pt ekranda sözü bölmeyen sütun sayısını seçer',
    (tester) async {
      await _pumpHome(tester);
      final repo = freshMockRepository();
      final tops = <double>{
        for (final c in repo.categories)
          tester.getTopLeft(find.byKey(ValueKey('home-topic-$c'))).dy,
      };
      // 2026-09-30: Paradigma, Siyaset ve Teknolojî geri gelince 10 kategori
      // oldu ve en uzun söz olan kalın "Paradigma" (~81 pt) 390 pt ekranda 4
      // sütunun karosuna (~80 pt) sığmadığı için ızgara 3 sütuna iniyordu
      // (3 + 3 + 3 + 1). Aynı gün Paradigma "Bilim ve Düşünce / Zanist û
      // Raman" adını aldı: ad iki satıra sarılır ama en uzun TEK söz artık
      // "Coğrafya" / "Erdnîgarî" (4 sütuna sığar), böylece ızgara 4 sütuna
      // döndü (`_columnsFor`): 10 kategori → 4 + 4 + 2.
      // 2026-09-30: 'Cîhan / Dünya' (nötr genel bilgi) on birinci kategori
      // olarak geldi: 11 kategori → 4 + 4 + 3 (yine ceil(11 / 4) satır).
      expect(repo.categories.length, 11);
      expect(tops.length, (repo.categories.length / 4).ceil());
    },
  );

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
