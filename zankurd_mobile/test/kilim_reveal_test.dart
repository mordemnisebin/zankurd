import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';
import 'package:zankurd_mobile/src/widgets/kilim_reveal.dart';

/// Kutlama katmanının sözleşmesi.
///
/// 2026-07-25 görsel denetimi: uygulamanın tek kutlama kanalı konfetiydi ve
/// konfeti her uygulamada aynı olduğu için ZanKurd'a ait bir şey
/// söylemiyordu. Bu katman marka dilini (kilim baklavası) kutlama jestine
/// çevirir.
///
/// Testler üç şeyi sabitler: desen yalnız kutlanacak sonuçta çizilir,
/// dekoratif olduğu için ekran okuyucudan gizlenir, hareket azaltma
/// tercihinde animasyon üretmez.
void main() {
  Widget wrap(Widget child) => MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(body: child),
  );

  testWidgets('kutlama varken desen çizilir', (tester) async {
    await tester.pumpWidget(
      wrap(const KilimReveal(active: true, child: Text('Tebrikler'))),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const ValueKey('kilim-reveal-motif')), findsOneWidget);
    expect(find.text('Tebrikler'), findsOneWidget);
  });

  testWidgets('kutlanacak bir şey yoksa desen hiç çizilmez', (tester) async {
    // Kaybedilen turda kutlama deseni açmak sonucu yanlış okur.
    await tester.pumpWidget(
      wrap(const KilimReveal(active: false, child: Text('Bu sefer olmadı'))),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('kilim-reveal-motif')), findsNothing);
    expect(find.text('Bu sefer olmadı'), findsOneWidget);
  });

  testWidgets('desen dekoratiftir — ekran okuyucuya sızmaz', (tester) async {
    await tester.pumpWidget(
      wrap(const KilimReveal(active: true, child: Text('Tebrikler'))),
    );
    await tester.pump(const Duration(milliseconds: 300));

    // Sonucun kendisi metinle okunur; desen semantik ağaçta yer almamalı.
    expect(find.byType(ExcludeSemantics), findsWidgets);
    expect(find.byType(IgnorePointer), findsWidgets);
  });

  testWidgets('hareket azaltma açıkken animasyon çalışmaz', (tester) async {
    await tester.pumpWidget(
      wrap(
        const KilimReveal(
          active: true,
          reducedMotion: true,
          child: Text('Tebrikler'),
        ),
      ),
    );
    // pumpAndSettle sürmekte olan bir animasyon varsa zaman aşımına
    // uğrardı; hareketsiz kipte desen ilk karede tam açık durur.
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('kilim-reveal-motif')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('animasyon tamamlanır ve istisna bırakmaz', (tester) async {
    await tester.pumpWidget(
      wrap(const KilimReveal(active: true, child: SizedBox(height: 200))),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
