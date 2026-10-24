import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';
import 'package:zankurd_mobile/src/widgets/sahne/sahne_foundation.dart';
import 'package:zankurd_mobile/src/widgets/sahne/sahne_vivid.dart';

/// Mod kartları büyük yazıda tek sütuna iner (2026-10-23).
///
/// ## Kusur
///
/// iPhone 17e'de iOS "çok çok büyük" yazı (~1,35 ölçek) ile Yarış
/// ekranındaki iki sütunlu kartlarda Kurmancî başlık "Hevalê xwe vexwîne
/// pêş…" ve rozet "Amade…" diye kesiliyordu. Tek sütun eşiği 1,6'ydı.
///
/// ## Niçin sessiz kalabilirdi
///
/// Testler 1,0 ölçekte koşar; büyük yazı turu yalnız simülatörde yapılıyordu.
///
/// ## Bekçi
///
/// 1,35 ölçekte iki kart alt alta durur (aynı satırda değil); 1,0'da yan yana.
void main() {
  Future<List<Offset>> pump(WidgetTester tester, double scale) async {
    await tester.binding.setSurfaceSize(const Size(375, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: MediaQuery(
          data: MediaQueryData(
            size: const Size(375, 900),
            textScaler: TextScaler.linear(scale),
          ),
          child: Scaffold(
            body: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SahneModeGrid(
                  children: [
                    SahneModeTile(
                      key: const ValueKey('a'),
                      role: SahneRole.race,
                      icon: Icons.timer,
                      title: 'Pêşbirka bi dorê',
                      onTap: () {},
                    ),
                    SahneModeTile(
                      key: const ValueKey('b'),
                      role: SahneRole.social,
                      icon: Icons.people,
                      title: 'Hevalê xwe vexwîne pêşbirkê',
                      onTap: () {},
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return [
      tester.getTopLeft(find.byKey(const ValueKey('a'))),
      tester.getTopLeft(find.byKey(const ValueKey('b'))),
    ];
  }

  testWidgets('normal yazıda yan yana', (tester) async {
    final p = await pump(tester, 1.0);
    expect(p[0].dy, p[1].dy);
  });

  testWidgets('iOS çok çok büyük yazıda alt alta', (tester) async {
    final p = await pump(tester, 1.35);
    expect(p[1].dy, greaterThan(p[0].dy));
    expect(p[0].dx, p[1].dx);
  });
}
