import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';
import 'package:zankurd_mobile/src/config/app_config.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/l10n/strings.dart';
import 'package:zankurd_mobile/src/screens/paywall_screen.dart';
import 'package:zankurd_mobile/src/screens/settings_screen.dart';
import 'package:zankurd_mobile/src/services/premium_service.dart';
import 'package:zankurd_mobile/src/widgets/branded_loader.dart';
import 'package:zankurd_mobile/src/widgets/legal_links.dart';

import 'support/widget_test_helpers.dart';

/// Simülatör düğme turu (2026-10-21) üç sessiz düğme buldu.
///
/// 1. Paywall'da paketler yüklenemeyince "Tekrar dene" ve "Satın alımları geri
///    yükle" basılınca GÖRÜNÜR bir şey olmuyordu: ağ hemen yine hata verince
///    gösterge bir karede kaybolup aynı kart yeniden çiziliyor, geri yükleme
///    ise sürerken gösterge, bitince mesaj vermiyordu.
/// 2. Hukuk bağlantıları dar satırda alt alta düşünce "·" ayracı tek başına
///    bir satıra kalıyordu.
/// 3. `mailto:` açılamayınca yalnız "Bağlantı açılamadı" çıkıyordu; kullanıcı
///    adrese ulaşamıyordu.
///
/// Bekçiler sahte servis / sahte url_launcher ile bunları ölçer.
void main() {
  late UrlLauncherPlatform original;
  setUp(() => original = UrlLauncherPlatform.instance);
  tearDown(() => UrlLauncherPlatform.instance = original);

  Future<void> pumpPaywall(WidgetTester tester, void Function() onFetch) async {
    await tester.binding.setSurfaceSize(const Size(390, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final service = PremiumService.forTesting(
      isAnonymous: () async => true,
      logOut: () async => throw UnimplementedError(),
      fetchOfferings: () async {
        onFetch();
        throw Exception('ağ yok');
      },
    );
    await tester.pumpWidget(
      testShell(
        child: PaywallScreen(repository: MockZanKurdRepository()),
        premiumService: service,
        languageProvider: turkishLang(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Tekrar dene: gösterge görünür, sonra hata kartı yeniden çıkar', (
    tester,
  ) async {
    var fetches = 0;
    await pumpPaywall(tester, () => fetches++);
    expect(fetches, 1);
    final retry = find.text(Tr.of(K.retry, AppLanguage.tr));
    expect(retry, findsOneWidget);

    await tester.tap(retry);
    await tester.pump(const Duration(milliseconds: 100));
    expect(fetches, 2);
    expect(
      find.byType(BrandedLoader),
      findsOneWidget,
      reason: 'hata yine hemen gelse bile gösterge görünür kalmalı',
    );
    expect(retry, findsNothing);

    await tester.pumpAndSettle();
    expect(find.byType(BrandedLoader), findsNothing);
    expect(retry, findsOneWidget, reason: 'hata kartı yeniden çizilir');
  });

  testWidgets('Geri yükle: sonuç SnackBar olarak görünür, düğme geri gelir', (
    tester,
  ) async {
    await pumpPaywall(tester, () {});
    final restore = find.text(Tr.of(K.restorePurchases, AppLanguage.tr));
    await tester.ensureVisible(restore);
    await tester.tap(restore);
    await tester.pumpAndSettle();

    // Testte RevenueCat yapılandırılmadığından sonuç `failed` olur.
    expect(find.text(Tr.of(K.paywallRestoreFailed, AppLanguage.tr)), findsOne);
    expect(
      find.byKey(const ValueKey('paywall-restore-progress')),
      findsNothing,
    );
    expect(restore, findsOneWidget);
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'hukuk bağlantılarında ayraç yalnız kalmaz (320 px, ${scale}x)',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 640));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          testShell(
            child: MediaQuery(
              data: MediaQueryData(
                size: const Size(320, 640),
                textScaler: TextScaler.linear(scale),
              ),
              child: const Scaffold(
                body: Center(
                  child: LegalLinksRow(alignment: MainAxisAlignment.center),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('·'), findsNothing);
        expect(find.text('Gizlilik politikası'), findsOneWidget);
        expect(find.text('Kullanım koşulları'), findsOneWidget);
      },
    );
  }

  for (final entry in {
    'settings-report-abuse': 'abuse',
    'settings-beta-feedback': 'feedback',
  }.entries) {
    testWidgets('mailto açılamazsa adres panoya kopyalanır (${entry.value})', (
      tester,
    ) async {
      UrlLauncherPlatform.instance = _NoApp();
      String? clipboard;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboard = (call.arguments as Map)['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await tester.binding.setSurfaceSize(const Size(390, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        testShell(
          child: SettingsScreen(repository: MockZanKurdRepository()),
          languageProvider: turkishLang(),
        ),
      );
      await tester.pumpAndSettle();
      final row = find.byKey(ValueKey(entry.key));
      await tester.scrollUntilVisible(
        row,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(row);
      await tester.pumpAndSettle();

      expect(clipboard, AppConfig.supportEmail);
      expect(
        find.text(
          Tr.of(K.roomCodeCopied, AppLanguage.tr, {
            'code': AppConfig.supportEmail,
          }),
        ),
        findsOneWidget,
      );
    });
  }
}

class _NoApp extends UrlLauncherPlatform {
  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async => false;
}
