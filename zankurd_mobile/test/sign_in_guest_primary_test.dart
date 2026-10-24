/// Giriş ekranının tek birincil eylemi "Hemen oyna" (misafir) olmalı.
///
/// ## Kusur
///
/// En büyük düğme "Google ile giriş yap"tı, misafir girişi küçük bir
/// bağlantıydı: yeni oyuncu oynamadan önce hesap açmaya itiliyordu
/// (Duolingo / Trivia Crack "önce oyna, hesap sonra" düzeninin tersi).
///
/// ## Niçin sessiz kaldı
///
/// Testler "misafir düğmesi görünür / dokununca girer" diyordu; hangi
/// eylemin ekranın BİRİNCİL eylemi olduğunu (alt perdede dolgulu düğme)
/// hiçbiri sormuyordu.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/screens/sign_in_screen.dart';

import 'support/realistic_device.dart';
import 'support/widget_test_helpers.dart';

void main() {
  setUpAll(loadAppFonts);

  testWidgets(
    'birincil eylem alt perdedeki "Hemen oyna"dır; girişler ikincil',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final auth = GateAuthProvider();
      await tester.pumpWidget(
        testShell(child: const SignInScreen(), authProvider: auth),
      );
      await tester.pumpAndSettle();

      final dock = find.byKey(const ValueKey('entry-dock'));
      expect(
        find.descendant(of: dock, matching: find.text('Hemen oyna')),
        findsOneWidget,
      );
      for (final secondary in [
        'Google ile giriş yap',
        'Apple ile giriş yap',
        'Hesabım var · Giriş yap',
      ]) {
        expect(
          find.descendant(of: dock, matching: find.text(secondary)),
          findsNothing,
          reason: '$secondary birincil perdede olmamalı',
        );
        expect(find.text(secondary), findsOneWidget);
      }

      await tester.tap(find.text('Hemen oyna'));
      await tester.pumpAndSettle();
      expect(auth.isAuthenticated, isTrue);
      debugDefaultTargetPlatformOverride = null;
    },
  );
}
