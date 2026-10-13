// 2026-10-01 kök neden: `main()` Supabase başlatmasına 4 sn'lik
// `bootStep` sınırı taktığı için, sınır AŞILDIĞI anda verilen
// `RemoteAvailability(reachable: false)` oturum boyunca kesinleşiyor ve
// bir daha hiç denenmiyordu. Soğuk açılışta başlatma yarışı yavaş bir
// cihazda bu sınırı rahat geçtiği için uygulama "Sunucuya ulaşılamadı"
// bandıyla açılıp sosyal yüzeyi kilitliyordu; kapatıp açmak yetiyordu.
//
// Bu dosya yeni sözleşmeyi kilitler: zaman aşımı GEÇİCİDİR — üstel
// geri çekilmeli yeniden deneme, ön plana dönüş ve kilitli eylem
// dokunuşu yoluyla kurtarma vardır; gerçek çevrimdışı ise yerinde kalır.
import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/sync_manager.dart';
import 'package:zankurd_mobile/src/providers/remote_availability.dart';
import 'package:zankurd_mobile/src/screens/app_shell.dart';

import 'support/widget_test_helpers.dart';

class _FixedConnectivityMonitor implements ConnectivityMonitor {
  const _FixedConnectivityMonitor(this.results);

  final List<ConnectivityResult> results;

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      const Stream.empty();

  @override
  Future<List<ConnectivityResult>> checkConnectivity() async => results;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RemoteAvailability kurtarma takvimi', () {
    test('ilk deneme zaman aşımına ugrasa da geri cekilen deneme ulasir', () {
      fakeAsync((async) {
        var probeCalls = 0;
        var upgrades = 0;
        var notified = 0;
        final hangingFirst = Completer<bool>();
        final availability = RemoteAvailability(
          reachable: false,
          probe: () {
            probeCalls += 1;
            // 1. deneme sonsuza dek asılı kalır (boot'un zaman aşımı
            // manzarası); 2. deneme ulaşır.
            if (probeCalls == 1) return hangingFirst.future;
            return Future<bool>.value(true);
          },
          retrySchedule: const [Duration(seconds: 2), Duration(seconds: 4)],
          onUpgradeRequest: () => upgrades += 1,
        );
        addTearDown(availability.dispose);
        availability.addListener(() => notified += 1);
        availability.startRetries();

        // 2 sn sonra ilk deneme başlar, asılı kalır.
        async.elapse(const Duration(seconds: 2));
        expect(probeCalls, 1, reason: 'ilk deneme 2 sn sonra başlamalı');
        expect(availability.reachable, isFalse);

        // 4 sn sonra zaman aşımı = denemenin SONU (karar değil), bir sonraki
        // geri çekilme 4 sn için planlanır.
        async.elapse(const Duration(seconds: 4));
        expect(probeCalls, 1, reason: 'asılı deneme hâlâ tek çağrı olmalı');

        async.elapse(const Duration(seconds: 4));
        async.flushMicrotasks();
        expect(probeCalls, 2, reason: 'geri çekilmiş deneme başlamalı');
        expect(
          availability.reachable,
          isTrue,
          reason: 'başarılı deneme kilidi kaldırmalı',
        );
        expect(notified, greaterThan(0), reason: 'dinleyiciler uyarılmalı');
        expect(upgrades, 1, reason: 'uzak oturum kurtarması bir kez istenmeli');
        expect(availability.retrying, isFalse, reason: 'takvim durmalı');
      });
    });

    test('ag gercekten yokken kilit yerinde kalir', () {
      fakeAsync((async) {
        var probeCalls = 0;
        final availability = RemoteAvailability(
          reachable: false,
          probe: () {
            probeCalls += 1;
            return Future<bool>.value(false);
          },
          retrySchedule: const [
            Duration(seconds: 1),
            Duration(seconds: 2),
            Duration(seconds: 3),
          ],
        );
        addTearDown(availability.dispose);
        availability.startRetries();

        async.elapse(const Duration(seconds: 10));

        // 1, 3, 6 ve 9. saniyelerde dört deneme; son eleman 3 sn ile
        // kendini tekrar eder (sonsuz aga baglanmak degil).
        expect(probeCalls, 4);
        expect(
          availability.reachable,
          isFalse,
          reason: 'gerçek çevrimdışı davranış değişmemeli',
        );
        expect(availability.retrying, isTrue, reason: 'takvim sürmeli');
      });
    });

    test('retryNow zaman beklemeden dener ve bildirir', () {
      fakeAsync((async) {
        var probeCalls = 0;
        var notified = 0;
        final availability = RemoteAvailability(
          reachable: false,
          probe: () {
            probeCalls += 1;
            return Future<bool>.value(true);
          },
          retrySchedule: const [Duration(seconds: 60)],
        );
        addTearDown(availability.dispose);
        availability.addListener(() => notified += 1);
        availability.startRetries();

        bool? result;
        unawaited(availability.retryNow().then((value) => result = value));
        async.flushMicrotasks();

        expect(probeCalls, 1, reason: 'zaman beklemeden hemen denemeli');
        expect(result, isTrue);
        expect(availability.reachable, isTrue);
        expect(notified, greaterThan(0));
        expect(availability.retrying, isFalse, reason: 'planlı takvim iptal');
      });
    });

    test('ulasilmis durumda retryNow yeniden deneme yapmaz', () {
      fakeAsync((async) {
        var probeCalls = 0;
        final availability = RemoteAvailability(
          reachable: true,
          probe: () {
            probeCalls += 1;
            return Future<bool>.value(false);
          },
        );
        addTearDown(availability.dispose);

        bool? result;
        unawaited(availability.retryNow().then((value) => result = value));
        async.flushMicrotasks();

        expect(result, isTrue);
        expect(probeCalls, 0, reason: 'zaten ulaşılırken ağa çağrı olmamalı');
      });
    });

    test('kurtarma kokte degilse ertelenir, koke donunce uygulanir', () {
      fakeAsync((async) {
        var upgrades = 0;
        var root = false;
        final availability = RemoteAvailability(
          reachable: false,
          probe: () => Future<bool>.value(true),
          onUpgradeRequest: () => upgrades += 1,
          isUpgradeSafe: () => root,
        );
        addTearDown(availability.dispose);

        unawaited(availability.retryNow());
        async.flushMicrotasks();
        expect(availability.reachable, isTrue, reason: 'ilk kurtarma başarılı');
        expect(
          upgrades,
          0,
          reason: 'üstte ekran açıkken kök yeniden kurulmamalı',
        );

        // Kullanıcı kabuğa döndü / ön plana çıktı.
        root = true;
        availability.considerUpgradeNow();
        expect(upgrades, 1, reason: 'kök boşalınca kurtarma uygulanmalı');

        availability.considerUpgradeNow();
        expect(upgrades, 1, reason: 'kurtarma ikinci kez tetiklenmemeli');
      });
    });

    test('dispose sonrasi deneme ve bildirim yapmaz', () {
      fakeAsync((async) {
        var probeCalls = 0;
        var notified = 0;
        final availability = RemoteAvailability(
          reachable: false,
          probe: () {
            probeCalls += 1;
            return Future<bool>.value(true);
          },
          retrySchedule: const [Duration(seconds: 2)],
        );
        availability.addListener(() => notified += 1);
        availability.startRetries();
        availability.dispose();

        async.elapse(const Duration(seconds: 10));
        async.flushMicrotasks();
        expect(probeCalls, 0, reason: 'zamanlayıcı iptal edilmiş olmalı');
        expect(notified, 0);
      });
    });
  });

  group('tek uçuşlu probe ve kurtarma sonucu', () {
    test('kurtarma uygulanamazsa karar geri alinir ve deneme surer', () async {
      late RemoteAvailability availability;
      var upgrades = 0;
      var applied = false;
      availability = RemoteAvailability(
        reachable: false,
        probe: () => Future<bool>.value(true),
        retrySchedule: const [Duration(milliseconds: 5)],
        onUpgradeRequest: () {
          upgrades += 1;
          if (applied) {
            availability.completeUpgrade();
          } else {
            // Örn. cihazda kayıtlı uzak oturum yok: takas yapılmaz.
            availability.upgradeDeclined();
          }
        },
      );
      addTearDown(availability.dispose);

      await availability.retryNow();
      expect(upgrades, 1, reason: 'kurtarma istenmeli');
      expect(
        availability.reachable,
        isFalse,
        reason: 'takas olmadan bant kalkmamalı',
      );
      expect(
        availability.retrying,
        isTrue,
        reason: 'yeniden deneme takvimi sürmeli',
      );

      // Kanca kapalı olmadığı için sonraki başarılı yoklama yeniden dener.
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(
        upgrades,
        greaterThanOrEqualTo(2),
        reason: 'uygulanamayan kurtarma ikinci kez denenmeli',
      );
      expect(availability.reachable, isFalse);

      final appliedCount = upgrades + 1;
      applied = true;
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(upgrades, appliedCount, reason: 'kurtarma bir kez uygulanmalı');
      expect(availability.reachable, isTrue, reason: 'uygulanınca bant kalkar');
      expect(availability.retrying, isFalse, reason: 'takvim durmalı');

      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(
        upgrades,
        appliedCount,
        reason: 'tamamlanınca kurtarma tekrar tetiklenmemeli',
      );
    });
  });

  group('AppShell üzerinden kurtarma', () {
    testWidgets('uzak kurtarma başlayınca sunucu bandı kalkar', (tester) async {
      SharedPreferences.setMockInitialValues({'zankurd.onboarding.seen': true});
      final availability = RemoteAvailability(
        reachable: false,
        probe: () => Future<bool>.value(true),
        retrySchedule: const [Duration(seconds: 60)],
      );
      addTearDown(availability.dispose);

      await tester.pumpWidget(
        testShell(
          authProvider: GateAuthProvider(),
          remoteAvailability: availability,
          child: AppShell(
            repository: freshMockRepository(),
            connectivityMonitor: const _FixedConnectivityMonitor([
              ConnectivityResult.wifi,
            ]),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Sunucuya ulaşılamadı'), findsOneWidget);

      // Soğuk açılışta zaman aşımı verdi, sonradan sunucu açıldı: arka
      // plan geriçekilmesi yerine elle/olay tetikli deneme.
      await availability.retryNow();
      await tester.pumpAndSettle();

      expect(
        find.text('Sunucuya ulaşılamadı'),
        findsNothing,
        reason: 'kurtarınca bant kendiliğinden kalkmalı',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('uygulama on plana donunce yeniden denenir', (tester) async {
      SharedPreferences.setMockInitialValues({'zankurd.onboarding.seen': true});
      var probeCalls = 0;
      final availability = RemoteAvailability(
        reachable: false,
        probe: () {
          probeCalls += 1;
          return Future<bool>.value(true);
        },
        retrySchedule: const [Duration(seconds: 60)],
      );
      addTearDown(availability.dispose);
      availability.startRetries();

      await tester.pumpWidget(
        testShell(
          authProvider: GateAuthProvider(),
          remoteAvailability: availability,
          child: AppShell(
            repository: freshMockRepository(),
            connectivityMonitor: const _FixedConnectivityMonitor([
              ConnectivityResult.wifi,
            ]),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(probeCalls, 0, reason: 'ilk geri çekilme 60 sn ötede');

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(probeCalls, 1, reason: 'ön plana dönüş hemen yoklamalı');
      expect(availability.reachable, isTrue);
      expect(find.text('Sunucuya ulaşılamadı'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
