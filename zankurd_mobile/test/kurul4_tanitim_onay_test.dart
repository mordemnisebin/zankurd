// Kurul 5. tur 2026-10-20: yaş kutusu standart yuvarlak kare (sekizgen kalktı).
// Kurul 4. tur 2026-10-20 (Opus, AI Studio): tanıtımda pasif "Sonraki"
// bozuk sanılıyordu. Pasif etiket ≥ 4.5:1 her iki temada hâlâ sabittir
// (başka ekranların pasif düğmeleri de bunu kullanır).
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

  // 2026-10-24: yaş kutusu kalktı (sahip kararı). Eski bekçi "Atla"nın kutuyu
  // delmemesini sınıyordu; artık kutu olmadığından "Atla" ve "Başla" doğrudan
  // tamamlar, ekranda hiçbir onay kutusu ya da uyarı kalmaz. Yaş şartı
  // Kullanım Şartları'nda ve giriş ekranındaki kabul satırında durur.
  testWidgets('"Atla" ilk dokunuşta tanıtımı bitirir; kutu ve uyarı yok', (
    tester,
  ) async {
    var completed = false;
    await pump(tester, () => completed = true);

    expect(find.byKey(const ValueKey('onboarding-age-gate')), findsNothing);
    expect(find.byKey(const ValueKey('onboarding-age-checkbox')), findsNothing);
    expect(find.byType(Checkbox), findsNothing);
    expect(find.textContaining('13 yaş'), findsNothing);

    await tester.tap(find.text('Atla'));
    await tester.pumpAndSettle();
    expect(completed, isTrue);
  });
}
