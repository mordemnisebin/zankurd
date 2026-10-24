// ignore_for_file: avoid_print, invalid_use_of_visible_for_testing_member
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/data/streak_store.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/providers/theme_provider.dart';
import 'package:zankurd_mobile/src/screens/settings_screen.dart';
import 'package:zankurd_mobile/src/services/email_verification.dart';
import 'package:zankurd_mobile/src/services/notification_service.dart';
import 'package:zankurd_mobile/src/widgets/email_verify_card.dart';
import 'package:zankurd_mobile/src/widgets/sahne/sahne.dart';
import 'package:zankurd_mobile/src/widgets/streak_calendar.dart';
import 'package:zankurd_mobile/src/widgets/streak_repair_card.dart';

import '../../test/support/widget_test_helpers.dart';

/// 2026-10-24: bildirim tercihleri, seri takvimi + onarım kartı ve e-posta
/// doğrulama kartı/kodu için ekran görüntüleri (açık/koyu, Türkçe/Kurmancî).
///
/// ```bash
/// ZANKURD_BSE_OUT_DIR=.tmp/bse flutter test \
///   tool/screenshots/bildirim_seri_eposta_preview_test.dart
/// ```
final _outDir = Platform.environment['ZANKURD_BSE_OUT_DIR'] ?? '.tmp/bse';
final _boundary = GlobalKey();

class _Gateway implements EmailVerificationGateway {
  @override
  String? get email => 'ada@example.com';
  @override
  bool get needsVerification => true;
  @override
  Future<bool?> isVerified() async => false;
  @override
  Future<void> sendCode() async {}
  @override
  Future<void> verifyCode(String code) async {}
  @override
  Future<bool> markVerified() async => true;
}

class _NoopNotif implements LocalNotificationGateway {
  @override
  Future<void> initialize(
    InitializationSettings settings,
    void Function(String? payload) onTap,
  ) async {}
  @override
  Future<String?> launchPayload() async => null;
  @override
  Future<void> zonedSchedule({
    required int id,
    required String title,
    required String body,
    required DateTime at,
    required NotificationDetails details,
    String? payload,
    bool repeatDaily = true,
  }) async {}
  @override
  Future<void> cancel(int id) async {}
  @override
  Future<void> cancelAll() async {}
}

class _Resolver implements TimeZoneResolver {
  @override
  Future<String?> resolve() async => 'Europe/Berlin';
}

Future<void> _shoot(WidgetTester tester, String name) async {
  await tester.runAsync(() async {
    final boundary =
        _boundary.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2.0);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('$_outDir/$name.png');
    await file.create(recursive: true);
    await file.writeAsBytes(data!.buffer.asUint8List());
  });
  print('✓ $name');
}

Future<void> _loadFonts() async {
  const families = {
    'Onest': [
      'assets/fonts/Onest-Regular.ttf',
      'assets/fonts/Onest-Medium.ttf',
      'assets/fonts/Onest-SemiBold.ttf',
      'assets/fonts/Onest-Bold.ttf',
    ],
    'BricolageGrotesque': [
      'assets/fonts/BricolageGrotesque-Bold.ttf',
      'assets/fonts/BricolageGrotesque-ExtraBold.ttf',
    ],
    'Lucide': ['assets/fonts/Lucide.ttf'],
  };
  for (final family in families.entries) {
    final loader = FontLoader(family.key);
    for (final path in family.value) {
      loader.addFont(
        File(path).readAsBytes().then((b) => ByteData.view(b.buffer)),
      );
    }
    await loader.load();
  }
}

Widget _app(Widget child, {required bool dark, required bool ku}) {
  return testShell(
    themeProvider: ThemeProvider(
      initialMode: dark ? ThemeMode.dark : ThemeMode.light,
    ),
    languageProvider: LanguageProvider()..setLang(ku ? 'ku' : 'tr'),
    child: Scaffold(
      body: SingleChildScrollView(
        child: RepaintBoundary(
          key: _boundary,
          child: Builder(
            builder: (context) => ColoredBox(
              color: SahneTokens.of(context).bg,
              child: Padding(padding: const EdgeInsets.all(16), child: child),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  setUpAll(_loadFonts);

  for (final dark in [false, true]) {
    for (final ku in [false, true]) {
      final tag = '${dark ? 'dark' : 'light'}_${ku ? 'ku' : 'tr'}';

      testWidgets('seri takvimi + onarım $tag', (tester) async {
        tester.view.devicePixelRatio = 2.0;
        tester.view.physicalSize = const Size(390, 1000) * 2;
        addTearDown(tester.view.reset);
        final today = DateTime(2026, 10, 24, 10);
        SharedPreferences.setMockInitialValues({
          'zankurd.streak.current': 9,
          'zankurd.streak.best': 9,
          'zankurd.streak.lastDay': '2026-10-22',
          'zankurd.streak.playedDays': [
            '2026-10-02',
            '2026-10-03',
            '2026-10-04',
            '2026-10-05',
            '2026-10-07',
            '2026-10-08',
            '2026-10-09',
            '2026-10-10',
            '2026-10-11',
            '2026-10-12',
            '2026-10-14',
            '2026-10-15',
            '2026-10-16',
            '2026-10-17',
            '2026-10-18',
            '2026-10-19',
            '2026-10-20',
            '2026-10-21',
            '2026-10-22',
          ],
          'zankurd.streak.frozenDays': ['2026-10-06', '2026-10-13'],
        });
        StreakStore.resetInstance();
        final store = await StreakStore.load();
        await tester.pumpWidget(
          _app(
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                StreakRepairCard(
                  store: store,
                  repository: MockZanKurdRepository(),
                  offer: store.repairOffer(now: today)!,
                  now: today,
                  onLater: () {},
                  onRepaired: (_) {},
                ),
                const SizedBox(height: 16),
                StreakCalendar(
                  markFor: (day) => store.markFor(day, now: today),
                  today: today,
                ),
              ],
            ),
            dark: dark,
            ku: ku,
          ),
        );
        await tester.pumpAndSettle();
        await _shoot(tester, 'streak_$tag');
      });

      testWidgets('e-posta kartı ve kod sayfası $tag', (tester) async {
        tester.view.devicePixelRatio = 2.0;
        tester.view.physicalSize = const Size(390, 700) * 2;
        addTearDown(tester.view.reset);
        SharedPreferences.setMockInitialValues({});
        await tester.pumpWidget(
          _app(
            EmailVerifyCard(gateway: _Gateway()),
            dark: dark,
            ku: ku,
          ),
        );
        await tester.pumpAndSettle();
        await _shoot(tester, 'email_card_$tag');
      });
    }
  }

  testWidgets('ayarlar bildirimler (koyu, Kurmancî)', (tester) async {
    tester.view.devicePixelRatio = 2.0;
    tester.view.physicalSize = const Size(390, 1300) * 2;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({'zankurd.language': 'ku'});
    NotificationService.resetInstance();
    final service = await NotificationService.load(
      timeZoneResolver: _Resolver(),
      gateway: _NoopNotif(),
    );
    await service.setEnabled(true);
    await tester.pumpWidget(
      RepaintBoundary(
        key: _boundary,
        child: testShell(
          themeProvider: ThemeProvider(initialMode: ThemeMode.dark),
          languageProvider: LanguageProvider()..setLang('ku'),
          child: SettingsScreen(repository: MockZanKurdRepository()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('settings-notif-social')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await _shoot(tester, 'settings_dark_ku');
    NotificationService.resetInstance();
  });
}
