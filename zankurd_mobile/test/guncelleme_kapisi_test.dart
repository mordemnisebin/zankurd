/// Zorunlu / yumuşak güncelleme kapısı ve bakım bandı (`UpdateGate`).
///
/// ## Kusur
///
/// Veri bozan ya da çöken bir sürüm çıkarsa eski sürümü kullananları
/// yükseltmeye zorlamanın yolu yoktu; ayrıca yeni sürümden habersiz kalan
/// kimseye söylenmiyordu (olcek_* denetimi, 2026-11).
///
/// ## Niçin sessiz kalırdı
///
/// Kapı olmayınca bozulacak bir şey de yoktu. Eklenirken iki yön kolay
/// yanlış gider: (1) build numarası okunamayan ya da uzak ayarı olmayan
/// cihazın KİLİTLENMESİ (çevrimdışı oyuncu uygulamadan atılır), (2) yumuşak
/// bandın her açılışta yeniden çıkması ya da yerleşimi ZIPLATMASI. Bu dosya
/// iki yönü ve "zorunlu ekran mağaza adresini açar" kuralını sabitler.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/config/app_config.dart';
import 'package:zankurd_mobile/src/config/runtime_config.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';
import 'package:zankurd_mobile/src/widgets/update_gate.dart';

import 'support/widget_test_helpers.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    RuntimeConfigService.debugReset();
  });

  Widget host(
    RuntimeConfigService service, {
    int? build = 40,
    TargetPlatform platform = TargetPlatform.iOS,
    void Function(String url)? onStore,
    LanguageProvider? lang,
  }) => MultiProvider(
    providers: [
      ChangeNotifierProvider<LanguageProvider>.value(
        value: lang ?? turkishLang(),
      ),
      ChangeNotifierProvider<RuntimeConfigService>.value(value: service),
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      home: UpdateGate(
        buildNumber: () async => build,
        platform: platform,
        openStore: (_, url) async => onStore?.call(url),
        child: const Scaffold(body: Center(child: Text('oyun'))),
      ),
    ),
  );

  testWidgets('build asgarinin altındaysa kök bloklanır, düğme mağazayı açar', (
    tester,
  ) async {
    final opened = <String>[];
    final service = RuntimeConfigService(
      initial: RuntimeConfig.fromJson(const {'min_supported_build_ios': 41}),
    );
    await tester.pumpWidget(host(service, onStore: opened.add));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('update-required-screen')),
      findsOneWidget,
    );
    expect(find.text('Güncelleme gerekli'), findsOneWidget);
    expect(find.text('oyun'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('update-required-store')));
    expect(opened, [AppConfig.appStoreUrl]);
  });

  testWidgets('Android mağaza adresi Play bağlantısıdır', (tester) async {
    final opened = <String>[];
    final service = RuntimeConfigService(
      initial: RuntimeConfig.fromJson(const {
        'min_supported_build_android': 41,
      }),
    );
    await tester.pumpWidget(
      host(service, platform: TargetPlatform.android, onStore: opened.add),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('update-required-store')));
    expect(opened, [AppConfig.playStoreUrl]);
  });

  testWidgets('build bilinmiyorsa ya da ayar yoksa HİÇBİR ŞEY çıkmaz', (
    tester,
  ) async {
    await tester.pumpWidget(host(RuntimeConfigService(), build: null));
    await tester.pumpAndSettle();
    expect(find.text('oyun'), findsOneWidget);
    expect(find.byKey(const ValueKey('update-required-screen')), findsNothing);

    final strict = RuntimeConfigService(
      initial: RuntimeConfig.fromJson(const {'min_supported_build_ios': 99}),
    );
    await tester.pumpWidget(host(strict, build: null));
    await tester.pumpAndSettle();
    expect(
      find.text('oyun'),
      findsOneWidget,
      reason: 'build okunamadı: kilit yok',
    );
  });

  testWidgets(
    'yumuşak bant: oyunu iterek değil üstüne biner, bir kez kapanır',
    (tester) async {
      final opened = <String>[];
      final service = RuntimeConfigService(
        initial: RuntimeConfig.fromJson(const {'latest_build_ios': 44}),
      );
      await tester.pumpWidget(host(service, onStore: opened.add));
      await tester.pumpAndSettle();
      final before = tester.getTopLeft(find.text('oyun'));
      expect(find.byKey(const ValueKey('update-soft-banner')), findsOneWidget);
      expect(find.text('oyun'), findsOneWidget, reason: 'oyun engellenmez');
      expect(tester.getTopLeft(find.text('oyun')), before);

      await tester.tap(find.byTooltip('Kapat'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('update-soft-banner')), findsNothing);

      // Aynı build: yeniden çizim ve yeniden açılış bandı geri getirmez.
      await tester.pumpWidget(host(service));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('update-soft-banner')), findsNothing);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt(UpdateGate.dismissedBuildKey), 40);
    },
  );

  testWidgets('"Güncelle" mağazayı açar ve bandı bu build için kapatır', (
    tester,
  ) async {
    final opened = <String>[];
    final service = RuntimeConfigService(
      initial: RuntimeConfig.fromJson(const {'latest_build_ios': 44}),
    );
    await tester.pumpWidget(host(service, onStore: opened.add));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Güncelle'));
    await tester.pumpAndSettle();
    expect(opened, [AppConfig.appStoreUrl]);
    expect(find.byKey(const ValueKey('update-soft-banner')), findsNothing);
  });

  testWidgets('bakım iletisi engellemez, arayüz diline göre görünür', (
    tester,
  ) async {
    final service = RuntimeConfigService(
      initial: RuntimeConfig.fromJson(const {
        'maintenance_message_tr': 'Bakım var',
        'maintenance_message_ku': 'Lênihêrîn heye',
      }),
    );
    await tester.pumpWidget(host(service));
    await tester.pumpAndSettle();
    expect(find.text('Bakım var'), findsOneWidget);
    expect(find.text('oyun'), findsOneWidget);
    await tester.tap(find.byTooltip('Kapat'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('maintenance-banner')), findsNothing);
  });

  testWidgets(
    'uzak ayar sonradan gelince (tazeleme) kapı kendiliğinden kurulur',
    (tester) async {
      final service = RuntimeConfigService(
        fetcher: () async => {'min_supported_build_ios': 99},
      );
      await tester.pumpWidget(host(service));
      await tester.pumpAndSettle();
      expect(find.text('oyun'), findsOneWidget);
      await service.refresh();
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('update-required-screen')),
        findsOneWidget,
      );
    },
  );
}
