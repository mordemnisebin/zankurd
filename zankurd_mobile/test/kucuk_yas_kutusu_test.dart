/// 2026-10-01 tasarım denetimi, küçük düzeltmeler (2/3): tanıtımdaki yaş
/// kutusu ve "Başla" düğmesi.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/screens/onboarding_screen.dart';

/// Kutu işaretli mi: yuvarlak kare artık Checkbox değil; işaretliyken dolgu
/// turuncudur (kurul 5. tur 2026-10-20).
bool checked(WidgetTester tester) {
  final box = tester.widget<AnimatedContainer>(
    find.byKey(const ValueKey('onboarding-age-checkbox')),
  );
  final d = box.decoration! as ShapeDecoration;
  return d.color != null && d.color != Colors.transparent;
}

void main() {
  // ───────────────────────────────────────────────────────────────────────
  // 2) Yaş kutusu ve "Başla"
  // ───────────────────────────────────────────────────────────────────────
  //
  // Kurul 3. tur 2026-10-20: "Sonraki" da onaysız pasif; aşağıdaki son test onu sabitler.
  // KUSUR: "13 yaşında veya daha büyüğüm" işaretsizken "Başla" tam etkin görünüyordu;
  // koşul yalnız basınca, hata olarak çıkıyordu. NİÇİN SESSİZ: davranış
  // doğruydu (basınca ipucu çıkıyor, akış durmuyor) ve testler yalnız
  // davranışa baktı; düğmenin GÖRÜNÜŞÜ (pasif mi etkin mi) hiçbir testte
  // ölçülmedi.
  group('2) Yaş kutusu', () {
    Future<void> toLastPage(WidgetTester tester, {VoidCallback? done}) async {
      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => LanguageProvider()..setLang('tr'),
          child: MaterialApp(home: OnboardingScreen(onComplete: done ?? () {})),
        ),
      );
      await tester.pumpAndSettle();
      for (var i = 0; i < 6 && find.text('Başla').evaluate().isEmpty; i++) {
        // "Sonraki" yaş onayı olmadan pasif (kurul 3. tur): sayfalar
        // kaydırılarak geçilir, "Başla" yine kapıda kalır.
        await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
        await tester.pumpAndSettle();
      }
    }

    FilledButton startButton(WidgetTester tester) =>
        tester.widget<FilledButton>(
          find.ancestor(
            of: find.text('Başla'),
            matching: find.byType(FilledButton),
          ),
        );

    testWidgets(
      'kutu işaretsizken "Başla" pasif görünür, işaretlenince etkin',
      (tester) async {
        var completed = 0;
        await toLastPage(tester, done: () => completed++);

        expect(startButton(tester).onPressed, isNull);

        // Pasif düğmeye basmak yine ipucunu açar, akışı tamamlamaz.
        await tester.tap(find.text('Başla'));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('onboarding-age-gate-hint')),
          findsOneWidget,
        );
        expect(completed, 0);

        await tester.tap(find.byKey(const ValueKey('onboarding-age-gate')));
        await tester.pumpAndSettle();
        expect(startButton(tester).onPressed, isNotNull);
        await tester.tap(find.text('Başla'));
        await tester.pumpAndSettle();
        expect(completed, 1);
      },
    );

    testWidgets(
      'kurul 3. tur: "Sonraki" yaş onayı olmadan pasif, onayla etkin',
      (tester) async {
        await tester.pumpWidget(
          ChangeNotifierProvider(
            create: (_) => LanguageProvider()..setLang('tr'),
            child: MaterialApp(home: OnboardingScreen(onComplete: () {})),
          ),
        );
        await tester.pumpAndSettle();
        FilledButton next() => tester.widget<FilledButton>(
          find.ancestor(
            of: find.text('Sonraki'),
            matching: find.byType(FilledButton),
          ),
        );
        expect(next().onPressed, isNull);
        // Onaysız basış sayfayı çevirmez, ipucunu açar.
        await tester.tap(find.text('Sonraki'));
        await tester.pumpAndSettle();
        expect(find.text('Sonraki'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('onboarding-age-gate-hint')),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const ValueKey('onboarding-age-gate')));
        await tester.pumpAndSettle();
        expect(next().onPressed, isNotNull);
        // Onay kutusu ekran okuyucuya işaretli olarak bildirilir.
        expect(
          find.byWidgetPredicate(
            (w) => w is Semantics && w.properties.checked == true,
          ),
          findsWidgets,
        );
      },
    );

    testWidgets('satırın her yeri kutuyu işaretler (yalnız kutucuk değil)', (
      tester,
    ) async {
      await toLastPage(tester);
      final row = find.byKey(const ValueKey('onboarding-age-gate'));
      final rect = tester.getRect(row);

      // Sağ uç, kutucuğun çok uzağında.
      await tester.tapAt(Offset(rect.right - 12, rect.center.dy));
      await tester.pumpAndSettle();
      expect(checked(tester), isTrue);

      // Etiket metnine basmak da geri alır.
      await tester.tap(find.text('13 yaşında veya daha büyüğüm'));
      await tester.pumpAndSettle();
      expect(checked(tester), isFalse);
    });
  });
}
