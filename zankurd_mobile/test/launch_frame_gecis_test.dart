// Kusur: soğuk açılışta yerel açılış ekranı (koyu zemin, büyük turuncu logo)
// -> BootHost (açık zemin, küçük logo + yazı + yükleyici) -> SplashScreen
// (üçüncü, farklı marka karesi) görünür sıçrama yaratıyordu.
// Niçin sessiz: her kare tek başına doğru; sıçrama yalnız yan yana görülür.
//
// Bekçi 1: LaunchFrame sabitleri yerel açılış ekranı dosyalarından okunan
//   değerlerle birebir (zemin rengi, logo boyutu).
// Bekçi 2: BootHost'un ilk karesi sistem parlaklığına göre o zemini ve
//   logoyu tam ortada, o boyutta çizer; yükleyici başta görünmez.
// Bekçi 3: BootHost kökle yer değiştirince arada ikinci bir SplashScreen
//   yoktur; SplashScreen de aynı kareyi çizer (ikinci marka karesi yok).
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/screens/splash_screen.dart';
import 'package:zankurd_mobile/src/widgets/boot_host.dart';
import 'package:zankurd_mobile/src/widgets/launch_frame.dart';

Color _hex(String h) => Color(0xFF000000 | int.parse(h, radix: 16));

void main() {
  test('sabitler iOS/Android açılış ekranı dosyalarıyla aynı', () {
    final colorset = File(
      'ios/Runner/Assets.xcassets/LaunchBackground.colorset/Contents.json',
    ).readAsStringSync();
    // İlk renk açık, ikincisi koyu tema.
    final comps = RegExp(
      r'"blue" : "0x(..)",\s*"green" : "0x(..)",\s*"red" : "0x(..)"',
    ).allMatches(colorset).map((m) => _hex('${m[3]}${m[2]}${m[1]}')).toList();
    expect(comps, [LaunchFrame.lightBackground, LaunchFrame.darkBackground]);

    final colors = File(
      'android/app/src/main/res/values/colors.xml',
    ).readAsStringSync();
    expect(
      _hex(RegExp(r'zk_splash_bg">#(\w+)').firstMatch(colors)![1]!),
      LaunchFrame.lightBackground,
    );
    expect(
      _hex(RegExp(r'zk_splash_bg_dark">#(\w+)').firstMatch(colors)![1]!),
      LaunchFrame.darkBackground,
    );

    // @3x görsel / 3 = yerel logo boyutu (pt).
    final png = File(LaunchFrame.logoAsset).readAsBytesSync();
    final w = ByteData.sublistView(png).getUint32(16);
    final h = ByteData.sublistView(png).getUint32(20);
    expect(w / 3, LaunchFrame.logoWidth);
    expect(h / 3, closeTo(LaunchFrame.logoHeight, 0.01));
    final ios3 = File(
      'ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage@3x.png',
    ).readAsBytesSync();
    expect(png, ios3, reason: 'Flutter logosu yerel logoyla aynı dosya');
  });

  for (final (label, brightness) in [
    ('açık', Brightness.light),
    ('koyu', Brightness.dark),
  ]) {
    testWidgets('BootHost ilk karesi yerel ekranla piksel uyumlu ($label)', (
      tester,
    ) async {
      tester.platformDispatcher.platformBrightnessTestValue = brightness;
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(BootHost(app: Completer<Widget>().future));

      final bg = tester.widget<ColoredBox>(
        find.byKey(const ValueKey('launch-frame-bg')),
      );
      expect(bg.color, LaunchFrame.backgroundFor(brightness));
      expect(
        tester.getSize(find.byKey(const ValueKey('launch-frame-bg'))),
        const Size(390, 844),
      );

      final logo = find.byKey(const ValueKey('launch-frame-logo'));
      expect(
        tester.getSize(logo),
        const Size(LaunchFrame.logoWidth, LaunchFrame.logoHeight),
      );
      expect(tester.getCenter(logo), const Offset(195, 422));

      // Yükleyici başta görünmez, gecikmeden sonra logoyu oynatmadan gelir.
      double spinnerOpacity() => tester
          .widget<AnimatedOpacity>(find.byType(AnimatedOpacity).last)
          .opacity;
      expect(spinnerOpacity(), 0);
      await tester.pump(
        LaunchFrame.spinnerDelay + const Duration(milliseconds: 1),
      );
      expect(spinnerOpacity(), 1);
      expect(tester.getCenter(logo), const Offset(195, 422));
      await tester.pump(const Duration(seconds: 1));
    });
  }

  testWidgets('BootHost -> kök arasında ikinci SplashScreen yok', (
    tester,
  ) async {
    final app = Completer<Widget>();
    await tester.pumpWidget(BootHost(app: app.future));
    app.complete(const MaterialApp(home: Text('KOK')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('KOK'), findsOneWidget);
    expect(find.byType(SplashScreen), findsNothing);
    expect(find.byKey(const ValueKey('boot-frame')), findsNothing);
  });

  testWidgets('SplashScreen aynı kareyi çizer; yazı yok', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SplashScreen(
          next: SizedBox.shrink(),
          duration: Duration(hours: 1),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(LaunchFrame), findsOneWidget);
    expect(find.text('ZanKurd'), findsNothing);
    await tester.pump(const Duration(hours: 1));
    await tester.pumpAndSettle();
  });
}
