// Kusur: koyu sistemde, uygulama içi tema AÇIK iken açılış koyu zeminle
// başlayıp (yerel ekran + BootHost) ikinci aşamada (tema yüklenince BootHost
// ya da SplashScreen) BEYAZ zemine dönüyordu: koyu -> beyaz -> ana sayfa
// (2026-11-03 simülatör kareleri f2-f7).
// Niçin sessiz: yerel açılış ekranı uygulama temasını bilemez; testler
// yalnız tek bir temada tek kare ölçüyordu, aşamalar arası geçişi değil.
//
// Sözleşme: kök (ana sayfa) gelene dek BÜTÜN kareler platform parlaklığını
// izler; uygulama temasına geçiş yalnız kök geçişinde olur.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/screens/splash_screen.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';
import 'package:zankurd_mobile/src/widgets/boot_host.dart';
import 'package:zankurd_mobile/src/widgets/launch_frame.dart';

void main() {
  testWidgets('platform koyu + uygulama teması açık: köke dek hep koyu', (
    tester,
  ) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearAllTestValues);

    final app = Completer<Widget>();
    await tester.pumpWidget(BootHost(app: app.future));

    Color bg() => tester
        .widget<ColoredBox>(find.byKey(const ValueKey('launch-frame-bg')))
        .color;

    expect(bg(), LaunchFrame.darkBackground);
    await tester.pump(const Duration(seconds: 2));
    expect(bg(), LaunchFrame.darkBackground);

    // Kök: uygulama teması AÇIK; SplashScreen ilk karesi hâlâ koyu.
    final readiness = Completer<void>();
    app.complete(
      MaterialApp(
        theme: AppTheme.light(),
        themeMode: ThemeMode.light,
        home: SplashScreen(
          next: const Scaffold(body: Text('ANA')),
          readiness: readiness.future,
        ),
      ),
    );
    // Solma boyunca (BootHost AnimatedSwitcher) her karede zemin koyu.
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      for (final e
          in find.byKey(const ValueKey('launch-frame-bg')).evaluate()) {
        expect((e.widget as ColoredBox).color, LaunchFrame.darkBackground);
      }
    }
    await tester.pump(const Duration(seconds: 1));
    expect(bg(), LaunchFrame.darkBackground);
    expect(
      tester.widget<Scaffold>(find.byType(Scaffold).last).backgroundColor,
      LaunchFrame.darkBackground,
    );

    // Geçiş yalnız hazır olunca: gerçek kök açık temada çizilir.
    readiness.complete();
    await tester.pumpAndSettle();
    expect(find.text('ANA'), findsOneWidget);
    expect(find.byKey(const ValueKey('launch-frame-bg')), findsNothing);
  });
}
