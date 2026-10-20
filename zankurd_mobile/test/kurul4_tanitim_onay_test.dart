// Kurul 5. tur 2026-10-20: yaş kutusu standart yuvarlak kare (sekizgen kalktı).
// Kurul 4. tur 2026-10-20 (Opus, AI Studio): tanıtımda pasif "Sonraki"
// bozuk sanılıyordu. Bu bekçi dördünü sabitler: (1) pasif etiket ≥ 4.5:1 her
// iki temada, (2) "Atla" yaş onayını DELMEZ (kusur olasılığı: Atla doğrudan
// onComplete çağırırsa 13 yaş kutusu atlanır), (3) bütün onay satırı ≥ 48
// yüksek dokunma hedefi ve kutu büyütülmüş, (4) kutu işaretlenene kadar
// nedeni altında yazar.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/screens/onboarding_screen.dart';
import 'package:zankurd_mobile/src/theme/sahne.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  for (final t in [SahneTokens.day, SahneTokens.night]) {
    test('pasif düğme etiketi pasif dolgu üstünde ≥ 4.5:1', () {
      expect(
        _contrast(t.disabledFg, t.disabledFill),
        greaterThanOrEqualTo(4.5),
      );
    });
  }

  Future<void> pump(WidgetTester tester, VoidCallback done) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => LanguageProvider()..setLang('tr'),
        child: MaterialApp(home: OnboardingScreen(onComplete: done)),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('"Atla" yaş kutusu işaretsizken tanıtımı bitirmez', (
    tester,
  ) async {
    var completed = false;
    await pump(tester, () => completed = true);

    await tester.tap(find.text('Atla'));
    await tester.pumpAndSettle();
    expect(completed, isFalse, reason: 'Atla yaş onayını delmemeli');
    expect(
      find.byKey(const ValueKey('onboarding-age-gate-hint')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('onboarding-age-gate')));
    await tester.pump();
    await tester.tap(find.text('Atla'));
    await tester.pumpAndSettle();
    expect(completed, isTrue);
  });

  testWidgets('onay satırı ≥ 48 yüksek, kutu büyütülmüş; neden baştan yazar', (
    tester,
  ) async {
    await pump(tester, () {});
    final row = tester.getSize(
      find.byKey(const ValueKey('onboarding-age-gate')),
    );
    expect(row.height, greaterThanOrEqualTo(48));
    // Kurul 5. tur 2026-10-20: kutu standart yuvarlak kare (sekizgen
    // Material Checkbox kalktı), ≥ 28 px.
    final box = tester.getSize(
      find.byKey(const ValueKey('onboarding-age-checkbox')),
    );
    expect(box.width, greaterThanOrEqualTo(28));
    expect(find.byType(Checkbox), findsNothing);
    expect(
      find.text('Devam etmek için "13 yaşından büyüğüm" kutusunu işaretle.'),
      findsOneWidget,
    );
  });
}
