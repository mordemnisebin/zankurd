/// Ana ekranın renk kimliği bekçisi.
///
/// ## Kusur
///
/// Sahibi ana ekranı "renksiz" buldu: kapılar (`HomeDoorTile`) aksanın
/// yalnız %8-16'lık soluk bir tonunu zemin yapıyor, gerçek renk tek bir
/// 40×40 ikon karosunda yaşıyordu; konu karoları (`_HomeTopicTile`) beyaz
/// zemin + ince kenarlık + küçük bir ikon rozetiydi, kategori rengi orada
/// da yalnız 36×36'lık bir noktaydı.
///
/// ## Niçin sessiz kalırdı
///
/// Var olan testler yalnız ANAHTARLARI (`home-door-learn` var mı,
/// `home-topic-Ziman` var mı) ve DAVRANIŞI (dokununca doğru yere gidiyor
/// mu) doğruluyordu. Kapı beyaz da olsa, konu karosu gökkuşağı da olsa aynı
/// testler yeşil kalırdı — hiçbiri rengi ya da görseli ÖLÇMÜYORDU.
///
/// ## 2026-09-27
///
/// Sahibi renkli ve modern bir görünüm istedi: kapılar artık aksanın
/// TAMAMINI dolduran bir gradyan taşıyor, konu karoları kendi kategori
/// gradyanını ve (varsa) kendi kimlik fotoğrafını taşıyor. Bu dosya o
/// rengin GERÇEKTEN orada olduğunu ve okunabilir kaldığını ölçer.
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

import 'support/widget_test_helpers.dart' show freshMockRepository;

// Dil sabit Türkçe tutulur: karo isim metnini `CategoryNames.localized` ile
// yeniden üretip karşılaştıracağız, bu yüzden hangi dilde çizildiği testin
// kendisi kadar açık olmalı.
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

/// WCAG 2.x bağıl kontrast oranı. `AppColors._contrast` özel (private)
/// olduğu için burada aynı formül bağımsız yeniden yazılır —
/// `Color.computeLuminance()` zaten WCAG'ın göreli parlaklık formülünü
/// uygular, bekçi yalnız oranı (L1+0.05)/(L2+0.05) hesaplar.
double _contrast(Color a, Color b) {
  final l1 = a.computeLuminance();
  final l2 = b.computeLuminance();
  final hi = l1 > l2 ? l1 : l2;
  final lo = l1 > l2 ? l2 : l1;
  return (hi + 0.05) / (lo + 0.05);
}

/// Bir anahtarın altındaki İLK `Ink` süsünü (kapı/karo zemin gradyanı) bulur.
BoxDecoration _inkDecorationUnder(WidgetTester tester, Finder ancestor) {
  final ink = tester.widget<Ink>(
    find.descendant(of: ancestor, matching: find.byType(Ink)).first,
  );
  return ink.decoration! as BoxDecoration;
}

void main() {
  setUp(() {
    freshMockRepository();
  });

  group('kapılar (HomeDoorTile) — gradyan + kontrast', () {
    testWidgets(
      'her kapının Ink gradyanı kendi aksanıyla başlar, başlık beyazdır',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 1600));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final repo = freshMockRepository();
        await tester.pumpWidget(
          _wrap(
            HomeScreen(
              repository: repo,
              onOpenLearning: () async {},
              onOpenPlay: () {},
            ),
          ),
        );
        await tester.pump(const Duration(seconds: 1));

        for (final key in ['home-door-learn', 'home-door-play']) {
          final finder = find.byKey(ValueKey(key));
          expect(finder, findsOneWidget, reason: key);

          final tile = tester.widget<HomeDoorTile>(finder);
          final decoration = _inkDecorationUnder(tester, finder);
          final gradient = decoration.gradient;
          expect(gradient, isA<LinearGradient>(), reason: key);
          expect(
            (gradient! as LinearGradient).colors.first,
            tile.accent,
            reason: '$key gradyanının ilk rengi kendi aksanı olmalı',
          );

          final titleText = tester.widget<Text>(
            find.descendant(of: finder, matching: find.text(tile.title)),
          );
          expect(
            titleText.style?.color,
            Colors.white,
            reason: '$key başlığı beyaz olmalı',
          );
        }
      },
    );

    test(
      'beyaz ve %92 alfa-harmanlı beyaz, playGreen/playRed üstünde AA (4.5:1) geçer',
      () {
        // Kapı başlığı düz beyaz, alt satır beyaz@%92'dir; ikisi de gradyanın
        // en AÇIK ucu olan `accent` üstünde okunur (koyu uç `deep` daha
        // kolay geçer, bu yüzden ölçüm kasıtlı olarak zor duruma bakar).
        for (final accent in [AppTheme.playGreen, AppTheme.playRed]) {
          expect(
            _contrast(Colors.white, accent),
            greaterThanOrEqualTo(4.5),
            reason: 'beyaz başlık × $accent',
          );
          final blendedSubtitle = Color.alphaBlend(
            Colors.white.withValues(alpha: 0.92),
            accent,
          );
          expect(
            _contrast(blendedSubtitle, accent),
            greaterThanOrEqualTo(4.5),
            reason: 'beyaz@0.92 alt satır × $accent',
          );
        }
      },
    );
  });

  test(
    'filigranın altındaki en açık noktada da kapı metni AA (4.5:1) geçer',
    () {
      // Filigran (beyaz %12) kapının sağ-alt köşesinde durur ve alt satırın,
      // uzun başlıkta başlığın da sağ ucuna değer (tur görüntüsü, 2026-09-27).
      // Gradyan orada koyulaşmıştır; ölçüm filigranın metne değebildiği en
      // açık noktaya, gradyanın %45'ine bakar.
      for (final accent in [AppTheme.playGreen, AppTheme.playRed]) {
        final deep = Color.lerp(accent, Colors.black, 0.28)!;
        final base = Color.lerp(accent, deep, 0.45)!;
        final underMark = Color.alphaBlend(
          Colors.white.withValues(alpha: 0.12),
          base,
        );
        expect(
          _contrast(Colors.white, underMark),
          greaterThanOrEqualTo(4.5),
          reason: 'başlık × filigran × $accent',
        );
        expect(
          _contrast(
            Color.alphaBlend(Colors.white.withValues(alpha: 0.92), underMark),
            underMark,
          ),
          greaterThanOrEqualTo(4.5),
          reason: 'alt satır × filigran × $accent',
        );
      }
    },
  );

  group('konu karoları (HomeTopicGrid) — kategori kimliği', () {
    testWidgets(
      'her görünür kategori kendi gradyanını taşır; kendi fotoğrafı olan '
      'kategoriler o fotoğrafı, olmayanlar kendi ikonunu gösterir',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 1600));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final repo = freshMockRepository();
        await tester.pumpWidget(
          _wrap(
            HomeScreen(
              repository: repo,
              onOpenLearning: () async {},
              onOpenPlay: () {},
            ),
          ),
        );
        await tester.pump(const Duration(seconds: 1));

        expect(repo.categories, isNotEmpty);
        // Bu ürünün bilinen görünür kümesi Sînema'yı içerir (Paradigma,
        // Siyaset, Teknolojî `hiddenCategoryIds` ile gizli); bekçi gizli
        // kümeyi bilerek varsaymaz, doğrudan repodan okur — liste ileride
        // değişirse test kırılmaz, gerçek kaynağı izler.
        expect(repo.categories, contains('Sînema'));

        for (final category in repo.categories) {
          final finder = find.byKey(ValueKey('home-topic-$category'));
          expect(finder, findsOneWidget, reason: category);

          final decoration = _inkDecorationUnder(tester, finder);
          final gradient = decoration.gradient;
          expect(gradient, isA<LinearGradient>(), reason: category);
          expect(
            (gradient! as LinearGradient).colors,
            CategoryVisuals.gradient(category).colors,
            reason: '$category karosu kendi gradyanını taşımalı',
          );

          final name = CategoryNames.localized(category, false);
          final nameText = tester.widget<Text>(
            find.descendant(of: finder, matching: find.text(name)).first,
          );
          expect(
            nameText.style?.color,
            Colors.white,
            reason: '$category adı beyaz olmalı',
          );

          final imageFinder = find.descendant(
            of: finder,
            matching: find.byType(Image),
          );
          if (CategoryVisuals.hasOwnImage(category)) {
            expect(
              imageFinder,
              findsOneWidget,
              reason: '$category kendi fotoğrafını taşımalı',
            );
            final image = tester.widget<Image>(imageFinder);
            var provider = image.image;
            if (provider is ResizeImage) provider = provider.imageProvider;
            expect(provider, isA<AssetImage>(), reason: category);
            expect(
              (provider as AssetImage).assetName,
              CategoryVisuals.imagePath(category),
              reason: '$category görseli category_visuals ile eşleşmeli',
            );
          } else {
            expect(
              imageFinder,
              findsNothing,
              reason:
                  '$category ödünç görsel taşımamalı (bkz. '
                  'CategoryVisuals.hasOwnImage)',
            );
            expect(
              find.descendant(
                of: finder,
                matching: find.byIcon(CategoryVisuals.icon(category)),
              ),
              findsWidgets,
              reason: '$category yerine kendi ikonunu çizmeli',
            );
          }
        }

        // Sînema, Çand'ın çay/kilim fotoğrafını ÖDÜNÇ alır (bkz.
        // `_imagePaths`); kimlik karosunda bu, yanlış konuyu anlatır. Tile
        // bu yüzden fotoğraf değil kendi ikonunu (klaket) çizmeli.
        final sinema = find.byKey(const ValueKey('home-topic-Sînema'));
        expect(
          find.descendant(of: sinema, matching: find.byType(Image)),
          findsNothing,
        );
        expect(
          find.descendant(
            of: sinema,
            matching: find.byIcon(CategoryVisuals.icon('Sînema')),
          ),
          findsWidgets,
        );
      },
    );

    test('"X soru" alt metni (henüz başlanmamış karo) her tanımlı kategori '
        'renginde AA (4.5:1) geçer', () {
      // Bu değer 2026-09-27'de %90 alfa ile yazılmıştı: tam opaklıkta bile
      // sınırda duran Coğrafya (#9C6300, 5.00:1) ve Muzîk (#4C7A17) o
      // alfada 4.39:1 / 4.49:1'e düşüyordu — ikisi de bugün ekranda görünen
      // gerçek kategoriler, ikisi de AA'nın altında. `colorDefinedCategories`
      // üzerinden GİZLİ kategoriler de (Paradigma, Siyaset, Teknolojî)
      // dahil taranır ki biri görünür yapıldığında bekçi onu da görsün.
      for (final category in CategoryVisuals.colorDefinedCategories) {
        final accent = CategoryVisuals.color(category);
        final metaColor = Color.alphaBlend(
          Colors.white.withValues(alpha: 0.95),
          accent,
        );
        expect(
          _contrast(metaColor, accent),
          greaterThanOrEqualTo(4.5),
          reason: category,
        );
      }
    });
  });

  group('Zana (RojMascot) günün dersi hero\'sunda', () {
    testWidgets(
      'kartta tam olarak bir kez çizilir ve semantik ağaca düğüm eklemez',
      (tester) async {
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

        expect(find.byType(RojMascot), findsOneWidget);

        // Maskot kendi semantiğini eklemez: kartın tek eylemi
        // `home-daily-task-start` düğmesidir. `ExcludeSemantics` atası bunu
        // garanti eder — maskotun üstünde başka bir semantik düğüm yoksa
        // (`Semantics` sarmalayıcısı yoksa) çerçeve onu ebeveyninin
        // düğümüne birleştirmez, tamamen görünmez kalır.
        final mascotElement = tester.element(find.byType(RojMascot));
        final excludeAncestor = mascotElement
            .findAncestorWidgetOfExactType<ExcludeSemantics>();
        expect(
          excludeAncestor,
          isNotNull,
          reason: 'RojMascot bir ExcludeSemantics atası içinde olmalı',
        );
      },
    );
  });
}
