/// Ölçüm rızası sayfası ve 13 yaş beyanı (`StartupPrompts`, `AgeGate`).
///
/// ## Kusur
///
/// Analytics/Crashlytics varsayılan KAPALI (2026-10-29) ama kullanıcıya
/// hiç sorulmuyordu: izin yalnız Ayarlar'da gömülüydü, pratikte kimse
/// açmıyor, çökme ve kullanım verisi görünmez kalıyordu. Yaş beyanı ise
/// hiç yoktu; mağaza/COPPA 13 yaş altına sohbet, arkadaş ve kişiselleştirilmiş
/// ölçümün kapalı olmasını bekler.
///
/// 2026-11-04 (ikinci tur kurulu): cevap yokken sosyal yüzey de AÇIKTI;
/// soruyu kapatan çocuk sohbete ve arkadaş isteğine sessizce giriyordu.
/// Artık cevapsız = sosyal kapalı, ilk sosyal dokunuşta soru çıkar.
/// Öğrenme/tek kişilik oyun hiçbir durumda kapanmaz.
///
/// ## Niçin sessiz kalırdı
///
/// İkisi de "eksik özellik"ti: çökmez, hata üretmez. Eklenirken kolay
/// hatalar: sayfanın HER açılışta çıkması (mevcut kullanıcıyı bıktırır),
/// "Reddet"in bir şey yazmaması (sonraki açılışta yine sorulur), çocuk
/// beyanının yine de ölçümü açabilmesi (Ayarlar anahtarı ya da eski "evet"
/// seçimi) ve açılışın bu sorularla gecikmesi. Bu dosya hepsini sabitler.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/config/feature_flags.dart';
import 'package:zankurd_mobile/src/data/age_gate_store.dart';
import 'package:zankurd_mobile/src/providers/analytics_consent_provider.dart';
import 'package:zankurd_mobile/src/screens/friends_screen.dart';
import 'package:zankurd_mobile/src/widgets/startup_prompts.dart';

import 'support/widget_test_helpers.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AgeGate.debugSet(null);
    AnalyticsConsentProvider.isEnabled = false;
  });
  tearDown(() => AgeGate.debugSet(null));

  group('AgeGate', () {
    test('cevap yoksa sosyal KAPALI (çocuk değil ama onaylı da değil); '
        'açılış sorusu bir kez çıkar', () async {
      expect(AgeGate.isMinor, isFalse);
      expect(AgeGate.isAdult, isFalse);
      expect(FeatureGate.social, isFalse, reason: 'cevapsız sosyal açılmaz');
      expect(FeatureGate.chat, isFalse);
      expect(FeatureGate.socialVisible, isTrue, reason: 'giriş görünür');
      expect(await AgeGate.shouldAsk(), isTrue);
      await AgeGate.markAsked();
      expect(await AgeGate.shouldAsk(), isFalse, reason: 'ikinci kez sorulmaz');
      expect(AgeGate.isMinor, isFalse);
    });

    test('beyan diskte kalır ve yeniden yüklenince geçerli', () async {
      await AgeGate.declare(AgeDeclaration.minor);
      AgeGate.debugSet(null);
      expect(await AgeGate.load(), AgeDeclaration.minor);
      expect(AgeGate.isMinor, isTrue);
      expect(await AgeGate.shouldAsk(), isFalse);
    });

    test('13 altı: sohbet ve sosyal kapalı, 13 üstü: açık', () async {
      expect(FeatureGate.chat, isFalse, reason: 'cevap yok = kapalı');
      expect(FeatureGate.social, isFalse);
      await AgeGate.declare(AgeDeclaration.minor);
      expect(FeatureGate.chat, isFalse);
      expect(FeatureGate.social, isFalse);
      await AgeGate.declare(AgeDeclaration.adult);
      expect(FeatureGate.chat, isTrue);
      expect(FeatureGate.social, isTrue);
    });

    test(
      '13 altı: eski "evet" seçimi de ölçümü AÇMAZ, ayar da açamaz',
      () async {
        SharedPreferences.setMockInitialValues({
          'zankurd.analyticsConsent': true,
          'zankurd.crashReportsConsent': true,
          AgeGate.declarationKey: 'minor',
        });
        AgeGate.debugSet(null);
        final provider = await AnalyticsConsentProvider.load();
        expect(provider.enabled, isFalse);
        expect(provider.crashReportsEnabled, isFalse);
        expect(await provider.setEnabled(true), isFalse);
        expect(await provider.setCrashReportsEnabled(true), isFalse);
        expect(provider.enabled, isFalse);
        expect(AnalyticsConsentProvider.isEnabled, isFalse);
      },
    );
  });

  group('StartupPrompts', () {
    late BuildContext ctx;
    // `testShell` rıza sağlayıcısını MaterialApp'in ÜSTÜNDE kurar; alt sayfa
    // rotaları da onu okur. Sınanan sağlayıcı o örnektir.
    Widget host() => testShell(
      child: Builder(
        builder: (c) {
          ctx = c;
          return const Scaffold(body: Text('ana'));
        },
      ),
    );

    AnalyticsConsentProvider consentOf() =>
        ctx.read<AnalyticsConsentProvider>();

    // Tercih deposu gerçek asenkron iş yapar: sahte saatte kalan bekleyişler
    // `runAsync` ile akıtılır, sonra çerçeveler çizilir.
    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 6; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 30)),
        );
        await tester.pump(const Duration(milliseconds: 20));
        await tester.pumpAndSettle();
      }
    }

    Future<void> run(WidgetTester tester) async {
      unawaited_(StartupPrompts.run(ctx));
      await settle(tester);
    }

    testWidgets('mevcut kullanıcı: önce yaş, sonra rıza; ikisi de bir kez', (
      tester,
    ) async {
      await tester.pumpWidget(host());
      final consent = consentOf();
      await run(tester);
      expect(find.text('13 yaşından büyük müsün?'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('age-gate-yes')));
      await settle(tester);
      expect(AgeGate.declaration, AgeDeclaration.adult);

      expect(find.text('Uygulamayı birlikte geliştirelim'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('consent-accept')));
      await settle(tester);
      expect(consent.enabled, isTrue);
      expect(consent.crashReportsEnabled, isTrue);
      expect(find.text('ana'), findsOneWidget);

      // Aynı kullanıcı yeniden açınca ikisi de çıkmaz.
      await run(tester);
      expect(find.text('13 yaşından büyük müsün?'), findsNothing);
      expect(find.text('Uygulamayı birlikte geliştirelim'), findsNothing);
    });

    testWidgets(
      'sosyal özelliğe ilk dokunuşta cevapsız kullanıcıya yaş sorulur; '
      '"evet" izin verir, çarpı vermez',
      (tester) async {
        await tester.pumpWidget(host());
        bool? cleared;
        unawaited_(
          StartupPrompts.ensureAgeCleared(ctx).then((v) => cleared = v),
        );
        await settle(tester);
        expect(find.text('13 yaşından büyük müsün?'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('sahne-sheet-close')));
        await settle(tester);
        expect(cleared, isFalse, reason: 'soruyu kapatmak izin değildir');
        expect(FeatureGate.social, isFalse);

        // Cevapsız kaldıkça her sosyal denemede yeniden sorulur.
        unawaited_(
          StartupPrompts.ensureAgeCleared(ctx).then((v) => cleared = v),
        );
        await settle(tester);
        await tester.tap(find.byKey(const ValueKey('age-gate-yes')));
        await settle(tester);
        expect(cleared, isTrue);
        expect(FeatureGate.social, isTrue);
        expect(FeatureGate.chat, isTrue);
        // Cevaplayana bir daha sorulmaz.
        expect(await StartupPrompts.ensureAgeCleared(ctx), isTrue);
      },
    );

    testWidgets(
      'Arkadaşlar ekranı cevapsızken yaş sorar; "evet" listeyi açar',
      (tester) async {
        await tester.pumpWidget(
          testShell(child: FriendsScreen(repository: freshMockRepository())),
        );
        await settle(tester);
        expect(find.byKey(const ValueKey('age-gate-yes')), findsOneWidget);
        expect(
          find.byKey(const ValueKey('friends-age-unanswered')),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const ValueKey('age-gate-yes')));
        await settle(tester);
        expect(
          find.byKey(const ValueKey('friends-age-unanswered')),
          findsNothing,
        );
        expect(AgeGate.isAdult, isTrue);
      },
    );

    testWidgets('13 altı cevabı: ensureAgeCleared sormadan false verir', (
      tester,
    ) async {
      await tester.pumpWidget(host());
      AgeGate.debugSet(AgeDeclaration.minor);
      expect(await StartupPrompts.ensureAgeCleared(ctx), isFalse);
      await tester.pump();
      expect(find.text('13 yaşından büyük müsün?'), findsNothing);
    });

    testWidgets('"Şimdi değil": ölçüm kapalı kalır ve bir daha sorulmaz', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({AgeGate.declarationKey: 'adult'});
      AgeGate.debugSet(AgeDeclaration.adult);
      await tester.pumpWidget(host());
      final consent = consentOf();
      await run(tester);
      await tester.tap(find.byKey(const ValueKey('consent-decline')));
      await settle(tester);
      expect(consent.enabled, isFalse);
      expect(consent.crashReportsEnabled, isFalse);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('zankurd.analyticsConsent'), isFalse);
      expect(prefs.getBool(StartupPrompts.consentShownKey), isTrue);
      expect(await StartupPrompts.shouldShowConsent(), isFalse);
    });

    testWidgets(
      '13 altı beyanı: ölçüm anında kapanır, rıza sayfası HİÇ çıkmaz',
      (tester) async {
        await tester.pumpWidget(host());
        final consent = consentOf();
        await tester.runAsync(() async {
          await consent.setEnabled(true);
          await consent.setCrashReportsEnabled(true);
        });
        expect(consent.enabled, isTrue);
        await run(tester);
        await tester.tap(find.byKey(const ValueKey('age-gate-no')));
        await settle(tester);
        expect(AgeGate.isMinor, isTrue);
        expect(consent.enabled, isFalse);
        expect(consent.crashReportsEnabled, isFalse);
        expect(find.text('Uygulamayı birlikte geliştirelim'), findsNothing);
      },
    );

    testWidgets('kullanım analizi için eski AÇIK seçim varsa rıza sorulmaz', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        'zankurd.analyticsConsent': false,
        AgeGate.declarationKey: 'adult',
      });
      expect(await StartupPrompts.shouldShowConsent(), isFalse);
    });

    testWidgets(
      'sayfa kapatılırsa (çarpı) cevap yok sayılır, tekrar sorulmaz',
      (tester) async {
        await tester.pumpWidget(host());
        await run(tester);
        await tester.tap(find.byKey(const ValueKey('sahne-sheet-close')));
        await settle(tester);
        expect(AgeGate.declaration, isNull, reason: 'kısıtsız');
        expect(await AgeGate.shouldAsk(), isFalse, reason: 'bir kez sorulur');
      },
    );
  });

  test('ilk açılış akışı yaş adımını ve rıza sayfasını kabuğa bağlar', () {
    // Davranış testi AppShell'in ağır kurulumunu ister; burada bağlantının
    // silinmediğini kaynak düzeyinde sabitleriz (adım ve sayfa kabuktan çıkarsa
    // ne yaş beyanı ne rıza sorulur ve hiçbir test düşmezdi).
    final shell = _read('lib/src/screens/app_shell.dart');
    expect(shell, contains('StartupPrompts.run(context)'));
    expect(shell, contains('askAge: _askAge'));
    final first = _read('lib/src/screens/first_run_choice_screen.dart');
    expect(first, contains('AgeGate.declare'));
    final settings = _read('lib/src/screens/settings_screen.dart');
    expect(settings, contains('AgeGate.isMinor'));
  });
}

String _read(String path) => File(path).readAsStringSync();

void unawaited_(Future<void> f) {}
