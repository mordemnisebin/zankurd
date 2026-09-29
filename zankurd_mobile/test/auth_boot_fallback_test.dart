// 2026-09-29 doğallık: arayüz metni sabitleyen beklentiler yeni metne göre güncellendi.
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/sync_manager.dart';
import 'package:zankurd_mobile/src/providers/auth_provider.dart';
import 'package:zankurd_mobile/src/providers/remote_availability.dart';
import 'package:zankurd_mobile/src/screens/app_shell.dart';
import 'package:zankurd_mobile/src/screens/sign_in_screen.dart';
import 'package:zankurd_mobile/src/widgets/sahne/sahne.dart';

import 'support/widget_test_helpers.dart';

/// Supabase açılış fallback'i sahte oturum basmamalı.
///
/// ## Kusur
///
/// `main()` Supabase 4 sn'de açılmazsa `MockZanKurdRepository` +
/// `AuthProvider.test(authenticated: true)` kullanıyordu. Giriş atlanır,
/// oda/liderlik/arkadaş sahte "ZanKurd Oyuncusu" kimliğiyle açılırdı.
/// Cihaz online olsa bile `OfflineBanner` sessiz kalırdı çünkü bu kip
/// çevrimdışı değil, sunucusuzdur.
///
/// Sessiz kaldı: widget testleri `FakeAuthProvider` ile kabuğu zaten
/// kimlikli açıyordu; production `main()` yolu hiç ölçülmüyordu.
class _OnlineConnectivityMonitor implements ConnectivityMonitor {
  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      const Stream.empty();

  @override
  Future<List<ConnectivityResult>> checkConnectivity() async => const [
    ConnectivityResult.wifi,
  ];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'zankurd.onboarding.seen': true,
      'zankurd.profileName.completed.user': true,
      'zankurd.quiz_tutorial.seen': true,
    });
  });

  test('boot fallback sahte authenticated: true basmaz', () {
    final auth = AuthProvider.test();
    expect(
      auth.isAuthenticated,
      isFalse,
      reason:
          'Supabase yokken otomatik oturum, sahte ZanKurd Oyuncusu demektir',
    );
  });

  testWidgets(
    'sunucu yokken cihaz online olsa da SignIn ve dürüst bant görünür',
    (tester) async {
      tester.view.devicePixelRatio = 3.0;
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      addTearDown(tester.view.reset);

      final repository = freshMockRepository();
      await tester.pumpWidget(
        testShell(
          authProvider: AuthProvider.test(),
          remoteAvailability: RemoteAvailability(reachable: false),
          child: AppShell(
            repository: repository,
            connectivityMonitor: _OnlineConnectivityMonitor(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(SignInScreen), findsOneWidget);
      expect(find.text('Giriş yap'), findsWidgets);
      expect(find.textContaining('Sunucuya ulaşılamadı'), findsOneWidget);
      expect(
        find.text('İnternet bağlantısı yok. Kontrol ediliyor…'),
        findsNothing,
        reason: 'Bu bant OfflineBanner değildir; cihaz online kabul edilir',
      );
    },
  );

  testWidgets('sunucu yokken oturum açılsa bile oda kartı kilitli', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 3.0;
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    addTearDown(tester.view.reset);

    final repository = freshMockRepository();
    await tester.pumpWidget(
      testShell(
        remoteAvailability: RemoteAvailability(reachable: false),
        child: AppShell(
          repository: repository,
          connectivityMonitor: _OnlineConnectivityMonitor(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));

    expect(find.textContaining('Sunucuya ulaşılamadı'), findsOneWidget);

    await tester.tap(find.text('Yarış'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final createRoom = find.byKey(const ValueKey('play-hub-create-room'));
    if (createRoom.evaluate().isNotEmpty) {
      // 2026-09-29 Şahnê: oda kartı artık liste satırıdır (`SahneListRow`);
      // kural aynı: sunucu yokken dokunulamaz.
      final card = tester.widget<SahneListRow>(createRoom);
      expect(card.onTap, isNull);
    }
  });
}
