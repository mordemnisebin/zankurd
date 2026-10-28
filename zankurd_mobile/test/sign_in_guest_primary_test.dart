/// Giriş ekranının tek birincil eylemi "Hemen oyna" (misafir) olmalı.
///
/// ## Kusur
///
/// En büyük düğme "Google ile giriş yap"tı, misafir girişi küçük bir
/// bağlantıydı: yeni oyuncu oynamadan önce hesap açmaya itiliyordu
/// (Duolingo / Trivia Crack "önce oyna, hesap sonra" düzeninin tersi).
///
/// ## 2026-10-28 K10 (geçersiz kılınan eski karar)
///
/// Eskiden Google + e-posta + parola + "Hesabım var" ilk karede yığılıydı ve
/// bu bekçi onların "perdede olmamasını" yeterli sayıyordu. Artık ilk
/// görünümde form ve sosyal girişler HİÇ yoktur; "Hesabım var · Giriş yap"a
/// basılınca açılır ve yine tek birincil düğme "Hemen oyna"dır.
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
import 'package:zankurd_mobile/src/widgets/sahne/sahne.dart';

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
      // 2026-10-28 K10: ilk görünümde YALNIZ "Hesabım var · Giriş yap"
      // (ikincil) görünür; Google/Apple ve e-posta formu o düğmeyle açılır.
      expect(
        find.descendant(
          of: dock,
          matching: find.text('Hesabım var · Giriş yap'),
        ),
        findsNothing,
        reason: 'ikincil giriş birincil perdede olmamalı',
      );
      expect(find.text('Hesabım var · Giriş yap'), findsOneWidget);
      for (final hidden in ['Google ile giriş yap', 'Apple ile giriş yap']) {
        expect(
          find.text(hidden),
          findsNothing,
          reason: '$hidden ilk karede yok',
        );
      }
      expect(find.byType(TextField), findsNothing);

      // Ekranda TEK turuncu birincil düğme: "Hemen oyna".
      final primaries = tester
          .widgetList<SahneButton>(find.byType(SahneButton))
          .where((b) => b.isPrimary)
          .toList();
      expect(primaries, hasLength(1));
      expect(primaries.single.label, 'Hemen oyna');

      // "Hesabım var" formu ve sosyal girişleri açar; birincil yine tek.
      await tester.tap(find.text('Hesabım var · Giriş yap'));
      await tester.pumpAndSettle();
      expect(find.text('Google ile giriş yap'), findsOneWidget);
      expect(find.text('Apple ile giriş yap'), findsOneWidget);
      expect(find.byType(TextField), findsNWidgets(2));
      expect(
        find.descendant(of: dock, matching: find.text('Hemen oyna')),
        findsOneWidget,
      );
      expect(
        tester
            .widgetList<SahneButton>(find.byType(SahneButton))
            .where((b) => b.isPrimary),
        hasLength(1),
      );

      await tester.tap(find.text('Hemen oyna'));
      await tester.pumpAndSettle();
      expect(auth.isAuthenticated, isTrue);
      debugDefaultTargetPlatformOverride = null;
    },
  );
}
