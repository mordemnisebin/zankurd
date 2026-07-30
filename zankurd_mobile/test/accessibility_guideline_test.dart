import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/data/placement_store.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/models/mini_guide.dart';
import 'package:zankurd_mobile/src/models/story.dart';
import 'package:zankurd_mobile/src/screens/level_placement_screen.dart';
import 'package:zankurd_mobile/src/screens/categories_tab.dart';
import 'package:zankurd_mobile/src/screens/home_screen.dart';
import 'package:zankurd_mobile/src/screens/learning_screen.dart';
import 'package:zankurd_mobile/src/screens/paywall_screen.dart';
import 'package:zankurd_mobile/src/screens/play_hub_screen.dart';
import 'package:zankurd_mobile/src/screens/profile_screen.dart';
import 'package:zankurd_mobile/src/screens/settings_screen.dart';
import 'package:zankurd_mobile/src/screens/shop_screen.dart';
import 'package:zankurd_mobile/src/screens/sign_in_screen.dart';
import 'package:zankurd_mobile/src/screens/story_screen.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';

import 'support/widget_test_helpers.dart';

Widget wrap(Widget child, {double textScale = 1.0}) => MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => LanguageProvider()..setLang('tr')),
  ],
  child: MaterialApp(
    theme: AppTheme.dark(),
    home: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: child,
    ),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PlacementStore.resetInstance();
  });

  testWidgets('seviye sınavı a11y kılavuzlarını karşılar', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      wrap(LevelPlacementScreen(repository: MockZanKurdRepository())),
    );
    await tester.pumpAndSettle();

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    handle.dispose();
  });

  testWidgets('hikâye ekranı a11y kılavuzlarını karşılar', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      wrap(StoryScreen(story: cayxaneStory, guide: cayxaneGuide)),
    );
    await tester.pumpAndSettle();

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    handle.dispose();
  });

  testWidgets('%200 metin ölçeğinde seviye sınavı overflow etmez', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        LevelPlacementScreen(repository: MockZanKurdRepository()),
        textScale: 2.0,
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('%200 metin ölçeğinde hikâye ekranı overflow etmez', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        StoryScreen(story: cayxaneStory, guide: cayxaneGuide),
        textScale: 2.0,
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('%200 metin ölçeğinde ana ekran ailesi overflow etmez', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);

    final repository = MockZanKurdRepository();
    final screens = <String, Widget>{
      'giriş': const SignInScreen(),
      'ana sayfa': Scaffold(body: HomeScreen(repository: repository)),
      'oyun merkezi': PlayHubScreen(repository: repository),
      'kategoriler': Scaffold(body: CategoriesTab(repository: repository)),
      'öğrenme': LearningScreen(repository: repository),
      'profil': Scaffold(body: ProfileScreen(repository: repository)),
      'ayarlar': SettingsScreen(repository: repository),
      'mağaza': ShopScreen(repository: repository),
      'premium': PaywallScreen(repository: repository),
    };

    for (final entry in screens.entries) {
      await tester.pumpWidget(
        testShell(
          child: MediaQuery(
            data: const MediaQueryData(
              size: Size(390, 844),
              textScaler: TextScaler.linear(2),
            ),
            child: entry.value,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      final error = tester.takeException();
      expect(error, isNull, reason: entry.key);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }
  });
}
