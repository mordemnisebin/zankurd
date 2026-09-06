/// Kategorilere tek kapı: ders yolunun içindeki keşif.
///
/// ## Kusur
///
/// Ana sayfada iki kart aynı işlevi (`_openCategories`) çağırıyordu:
/// "Konu seç" ve ilerleme yokken "Tüm kategoriler". Metinler ayrılınca
/// da iki kapı duruyordu. 2026-08-29: ürün kararı tek kahraman —
/// konu listesi yolun içinden açılır, ikinci kart yoktur.
///
/// ## Niçin sessiz kalırdı
///
/// İki kart ayrı dosyalardaydı; birim testleri yan yana gelince
/// ortaya çıkan çift kapıyı görmüyordu.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/l10n/strings.dart';
import 'package:zankurd_mobile/src/providers/auth_provider.dart';
import 'package:zankurd_mobile/src/providers/theme_provider.dart';
import 'package:zankurd_mobile/src/screens/home_screen.dart';
import 'package:zankurd_mobile/src/services/premium_service.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';

void main() {
  test('keşif metni Hawar alfabesinde', () {
    final text = Tr.forKu(K.homePathBrowse, true);
    expect(text.trim(), isNotEmpty);
    for (final bad in ['ı', 'ğ', 'ö', 'ü', 'İ']) {
      expect(
        text.contains(bad),
        isFalse,
        reason: 'Hawar dışı «$bad» harfi: "$text"',
      );
    }
  });

  testWidgets('ana sayfada konu listesine tek kapı vardır', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => LanguageProvider()),
          ChangeNotifierProvider(create: (_) => AuthProvider.test()),
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider<PremiumService>(
            create: (_) => PremiumService.fallback(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: HomeScreen(
            repository: MockZanKurdRepository(),
            onOpenCategories: () async {},
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));

    expect(find.byKey(const ValueKey('home-topic-picker')), findsNothing);
    expect(find.byKey(const ValueKey('home-discover-section')), findsNothing);
    expect(
      find.byKey(const ValueKey('home-browse-categories-row')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('home-lessons-row')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-zana')), findsOneWidget);
  });
}
