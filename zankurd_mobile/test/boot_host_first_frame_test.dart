// Kusur: `main()` `runApp`'ı Firebase/Supabase/RevenueCat/soru bankası
// future'ları bitene dek çağırmıyordu; ilk Flutter karesi ağ zaman
// sınırlarının TOPLAMINI bekliyordu (yavaş ağda saniyeler).
// Niçin sessiz: hızlı ağda/geliştirici cihazında toplam kısa kalır, ve hiçbir
// test `runApp`'ın uzak işlerden önce çalıştığını ölçmüyordu.
//
// Bekçi 1: BootHost, `app` future'ı TAMAMLANMADAN ilk kareyi çizer.
// Bekçi 2: oturum belli olana dek (kök hazır olmadan) giriş/çıkış arayüzü
//   ASLA çizilmez; oturumlu kullanıcı çıkış yapmış arayüz görmez.
// Bekçi 3 (kaynak sırası): main.dart'ta `runApp(BootHost` hiçbir uzak
//   `await`ten önce gelir.
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/widgets/boot_host.dart';

void main() {
  testWidgets('ilk kare, ağ future\'ı tamamlanmadan çizilir', (tester) async {
    final network = Completer<Widget>(); // asla kendiliğinden bitmez
    await tester.pumpWidget(BootHost(app: network.future));
    expect(find.byKey(const ValueKey('boot-frame')), findsOneWidget);
    expect(network.isCompleted, isFalse);
  });

  testWidgets('kök hazır olana dek ne giriş ne çıkış arayüzü çizilir', (
    tester,
  ) async {
    final session = Completer<Widget>();
    await tester.pumpWidget(BootHost(app: session.future));
    expect(find.text('LOGGED-OUT-UI'), findsNothing);
    expect(find.text('SIGNED-IN-HOME'), findsNothing);

    session.complete(const MaterialApp(home: Text('SIGNED-IN-HOME')));
    await tester.pump();
    expect(find.text('SIGNED-IN-HOME'), findsOneWidget);
    expect(find.text('LOGGED-OUT-UI'), findsNothing);
    expect(find.byKey(const ValueKey('boot-frame')), findsNothing);
  });

  testWidgets('kök kurulumu hata verirse yedek kök gelir', (tester) async {
    final failing = Completer<Widget>();
    await tester.pumpWidget(
      BootHost(
        app: failing.future,
        onError: (_) => const MaterialApp(home: Text('YEDEK')),
      ),
    );
    failing.completeError(StateError('x'));
    await tester.pump();
    expect(find.text('YEDEK'), findsOneWidget);
  });

  test('main.dart: runApp(BootHost uzak await\'lerden önce gelir', () {
    final src = File('lib/main.dart').readAsStringSync();
    final run = src.indexOf('runApp(\n        BootHost(');
    final main = src.indexOf('Future<void> main()');
    final bootApp = src.indexOf('Future<Widget> _bootApp()');
    expect(run, greaterThan(main));
    expect(run, lessThan(bootApp));
    // main() gövdesinde (runApp'tan önce) uzak init beklenmez.
    final before = src.substring(main, run);
    for (final bad in [
      'await Firebase',
      'await Supabase',
      'await questionBankFuture',
      'await premiumFuture',
      'await remoteReadyFuture',
    ]) {
      expect(before.contains(bad), isFalse, reason: bad);
    }
  });
}
