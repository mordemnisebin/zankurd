// "Doza me / Davamız" — kimlik ve değerler sayfası bekçisi (2026-10-21).
//
// ## Neyi korur
//
// Sayfa jüriden geçmiş metni AYNEN taşır; bir madde kaybolur, bir giriş
// noktası düşer ya da tarihî gün şeridi yanlış günde çıkarsa hiçbir derleme
// hatası olmaz — yalnız uygulamanın kimliği sessizce eksilir. Bekçi:
//   * sayfa KU ve TR'de giriş, sekiz madde, kapanış ve paylaş düğmesini çizer;
//   * paylaş düğmesi kapanış metni + mağaza bağlantılarını verir (zankurd.com değil);
//   * profil, ayarlar, ana sayfa slogan satırı ve onboarding girişi vardır;
//   * şerit YALNIZ 21 Şubat, 8/16/21 Mart ve 15 Mayıs'ta görünür
//     ([SahneClock] ile sabitlenir);
//   * 320 px + 2x yazıda taşma yok.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/data/sync_manager.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/l10n/strings.dart';
import 'package:zankurd_mobile/src/providers/auth_provider.dart';
import 'package:zankurd_mobile/src/providers/theme_provider.dart';
import 'package:zankurd_mobile/src/screens/doza_me_screen.dart';
import 'package:zankurd_mobile/src/screens/home_screen.dart';
import 'package:zankurd_mobile/src/screens/onboarding_screen.dart';
import 'package:zankurd_mobile/src/screens/profile_screen.dart';
import 'package:zankurd_mobile/src/screens/settings_screen.dart';
import 'package:zankurd_mobile/src/services/premium_service.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';
import 'package:zankurd_mobile/src/widgets/doza_widgets.dart';
import 'package:zankurd_mobile/src/widgets/sahne/sahne.dart';

import 'support/widget_test_helpers.dart';

const _itemKeys = [
  (K.dozaM1Head, K.dozaM1Body),
  (K.dozaM2Head, K.dozaM2Body),
  (K.dozaM3Head, K.dozaM3Body),
  (K.dozaM4Head, K.dozaM4Body),
  (K.dozaM5Head, K.dozaM5Body),
  (K.dozaM6Head, K.dozaM6Body),
  (K.dozaM7Head, K.dozaM7Body),
  (K.dozaM8Head, K.dozaM8Body),
];

Widget _homeShell(Widget child, {bool ku = false}) => MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => ku ? kurmanciLang() : turkishLang()),
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
  await tester.binding.setSurfaceSize(const Size(390, 3200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    _homeShell(
      HomeScreen(repository: freshMockRepository(), displayName: 'Zelal'),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 900));
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() async {
    SahneClock.now = () => DateTime(2026, 10, 21, 12);
    await SyncManager.resetForTesting();
  });

  for (final ku in [false, true]) {
    final lang = ku ? AppLanguage.ku : AppLanguage.tr;
    testWidgets('sayfa ${lang.code}: giriş, 8 madde, kapanış, paylaş', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(390, 6000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        testShell(
          languageProvider: ku ? kurmanciLang() : turkishLang(),
          child: const DozaMeScreen(),
        ),
      );
      await tester.pump();

      expect(find.text(Tr.of(K.dozaTitle, lang)), findsWidgets);
      expect(find.text(Tr.of(K.dozaIntro, lang)), findsOneWidget);
      expect(find.text(Tr.of(K.dozaRights, lang)), findsOneWidget);
      for (var i = 0; i < _itemKeys.length; i++) {
        final (head, body) = _itemKeys[i];
        expect(find.byKey(ValueKey('doza-item-${i + 1}')), findsOneWidget);
        expect(find.text(Tr.of(head, lang)), findsOneWidget, reason: head);
        expect(find.text(Tr.of(body, lang)), findsOneWidget, reason: body);
      }
      expect(find.byKey(const ValueKey('doza-closing')), findsOneWidget);
      expect(
        find.textContaining('Zimanê me nasnameya me ye.', findRichText: true),
        findsWidgets,
      );
      expect(find.byKey(const ValueKey('doza-share-button')), findsOneWidget);
      expect(find.text(Tr.of(K.dozaShare, lang)), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('paylaş düğmesi kapanış metni ve mağaza bağlantılarını verir', (
    tester,
  ) async {
    String? shared;
    await tester.pumpWidget(
      testShell(
        languageProvider: kurmanciLang(),
        child: DozaMeScreen(onShare: (text) async => shared = text),
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('doza-share-button')));
    await tester.pump();
    expect(
      shared,
      '${Tr.of(K.dozaClosing, AppLanguage.ku)}\n${DozaMeScreen.appLink}',
    );
    expect(shared, contains('apps.apple.com'));
    expect(shared, isNot(contains('zankurd.com')));
  });

  testWidgets('profilde Doza me girişi var ve sayfayı açar', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      testShell(
        child: Scaffold(
          body: ProfileScreen(repository: MockZanKurdRepository()),
        ),
      ),
    );
    final entry = find.byKey(const ValueKey('profile-doza-entry'));
    for (var i = 0; i < 40 && entry.evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(entry, findsOneWidget);
    await tester.tap(entry);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(DozaMeScreen), findsOneWidget);
  });

  testWidgets('ayarlarda Doza me satırı var ve sayfayı açar', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      testShell(child: SettingsScreen(repository: MockZanKurdRepository())),
    );
    await tester.pump(const Duration(milliseconds: 500));
    final row = find.byKey(const ValueKey('settings-doza-row'));
    await tester.scrollUntilVisible(
      row,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    await tester.tap(row);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(DozaMeScreen), findsOneWidget);
  });

  testWidgets('ana sayfa slogan satırı var ve dokununca sayfa açılır', (
    tester,
  ) async {
    await _pumpHome(tester);
    final slogan = find.byKey(const ValueKey('doza-slogan-line'));
    await tester.ensureVisible(slogan);
    await tester.pump();
    expect(find.text('Zimanê me nasnameya me ye.'), findsOneWidget);
    await tester.tap(slogan);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(DozaMeScreen), findsOneWidget);
  });

  testWidgets('onboarding ilk ekranında slogan başlığın altında', (
    tester,
  ) async {
    await tester.pumpWidget(
      testShell(child: OnboardingScreen(onComplete: () {})),
    );
    await tester.pumpAndSettle();
    final slogan = find.byKey(const ValueKey('onboarding-slogan'));
    expect(slogan, findsOneWidget);
    expect(find.text('Zimanê me nasnameya me ye.'), findsOneWidget);
    expect(
      tester.getTopLeft(slogan).dy,
      greaterThan(tester.getTopLeft(find.text('Öğren')).dy),
    );
  });

  group('tarihî gün şeridi', () {
    test('yalnız beş tarihte bir gün döner', () {
      expect(DozaDay.on(DateTime(2027, 2, 21)), DozaDay.languageDay);
      expect(DozaDay.on(DateTime(2027, 3, 8)), DozaDay.womenDay);
      expect(DozaDay.on(DateTime(2027, 3, 16)), DozaDay.halabja);
      expect(DozaDay.on(DateTime(2027, 3, 21)), DozaDay.newroz);
      expect(DozaDay.on(DateTime(2027, 5, 15)), DozaDay.languageFestival);
      for (final d in [
        DateTime(2027, 3, 20),
        DateTime(2027, 3, 22),
        DateTime(2027, 2, 20),
        DateTime(2027, 5, 14),
        DateTime(2027, 12, 21),
      ]) {
        expect(DozaDay.on(d), isNull, reason: '$d');
      }
    });

    testWidgets('21 Mart: Newroz şeridi görünür, dokununca sayfa açılır', (
      tester,
    ) async {
      SahneClock.now = () => DateTime(2027, 3, 21, 12);
      await _pumpHome(tester);
      final strip = find.byKey(const ValueKey('doza-day-newroz'));
      expect(strip, findsOneWidget);
      expect(find.text(Tr.of(K.dozaG1Text, AppLanguage.tr)), findsOneWidget);
      await tester.tap(strip);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(DozaMeScreen), findsOneWidget);
    });

    testWidgets('16 Mart: Halepçe anma şeridi', (tester) async {
      SahneClock.now = () => DateTime(2027, 3, 16, 12);
      await _pumpHome(tester);
      expect(find.byKey(const ValueKey('doza-day-halabja')), findsOneWidget);
      expect(find.text(Tr.of(K.dozaG3Sub, AppLanguage.tr)), findsOneWidget);
    });

    testWidgets('22 Mart: şerit yok', (tester) async {
      SahneClock.now = () => DateTime(2027, 3, 22, 12);
      await _pumpHome(tester);
      expect(find.byKey(const ValueKey('doza-day-newroz')), findsNothing);
      for (final d in DozaDay.values) {
        expect(find.byKey(ValueKey('doza-day-${d.name}')), findsNothing);
      }
    });
  });

  for (final ku in [false, true]) {
    testWidgets('320 px + 2x yazı: taşma yok (${ku ? 'ku' : 'tr'})', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        testShell(
          languageProvider: ku ? kurmanciLang() : turkishLang(),
          child: const MediaQuery(
            data: MediaQueryData(
              size: Size(320, 640),
              textScaler: TextScaler.linear(2),
            ),
            child: DozaMeScreen(),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      final scroll = find.byType(Scrollable).first;
      await tester.drag(scroll, const Offset(0, -6000));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  }
}
