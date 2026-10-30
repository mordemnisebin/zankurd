/// Giriş ekranının tek birincil eylemi "Misafir olarak devam et" (misafir) olmalı.
///
/// ## Kusur
///
/// En büyük düğme "Google ile giriş yap"tı, misafir girişi küçük bir
/// bağlantıydı: yeni oyuncu oynamadan önce hesap açmaya itiliyordu
/// (Duolingo / Trivia Crack "önce oyna, hesap sonra" düzeninin tersi).
///
/// ## T4 (2026-10-30)
/// Kullanıcı K10 gizleme kararını değiştirdi: sosyal yollar ilk karede,
/// misafirin altında; yalnız e-posta formu açılır. Alt perde zorunlu değil.
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
    'T4 ilk karede sosyal yollar gizliydi; K10 gizlemeyi başarı sayıyordu',
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

      for (final label in [
        'Misafir olarak devam et',
        'Apple ile devam et',
        'Google ile devam et',
        'E-posta ile giriş',
      ]) {
        expect(find.text(label).hitTestable(), findsOneWidget);
      }
      expect(find.byType(TextField), findsNothing);

      // Ekranda TEK turuncu birincil düğme: "Misafir olarak devam et".
      final primaries = tester
          .widgetList<SahneButton>(find.byType(SahneButton))
          .where((b) => b.isPrimary)
          .toList();
      expect(primaries, hasLength(1));
      expect(primaries.single.label, 'Misafir olarak devam et');

      // T4: form açılınca da misafir erişilebilir, artık ikincildir.
      await tester.tap(find.text('E-posta ile giriş'));
      await tester.pumpAndSettle();
      expect(find.text('Google ile devam et'), findsOneWidget);
      expect(find.text('Apple ile devam et'), findsOneWidget);
      expect(find.byType(TextField), findsNWidgets(2));
      expect(
        tester
            .widget<SahneButton>(find.byKey(const ValueKey('sign-in-play-now')))
            .isPrimary,
        isFalse,
      );
      expect(
        tester
            .widgetList<SahneButton>(find.byType(SahneButton))
            .where((b) => b.isPrimary),
        hasLength(1),
      );
      await tester.tap(find.text('Misafir olarak devam et'));
      await tester.pumpAndSettle();
      expect(auth.isAuthenticated, isTrue);
      debugDefaultTargetPlatformOverride = null;
    },
  );
}
