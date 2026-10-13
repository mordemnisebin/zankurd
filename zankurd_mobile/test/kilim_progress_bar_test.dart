import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';
import 'package:zankurd_mobile/src/theme/sahne.dart';
import 'package:zankurd_mobile/src/widgets/kilim_progress_bar.dart';

/// Kilim ilerleme çubuğunun görsel sözleşmesi.
///
/// Bu dosyanın ilk hâli "kültürel deseni gösterir" diye iddia ediyordu ama
/// tek kanıtı `find.byType(CustomPaint)` idi — Flutter iç bileşenleri
/// yüzünden desen hiç çizilmese de geçen bir kontrol. 2026-07-25 görsel
/// denetiminde bileşenin gövdesinin düz renkli bir çubuktan ibaret olduğu,
/// yani adının ve belgesinin var olmayan bir motifi vaat ettiği görüldü;
/// testin yanlış güveni bunun fark edilmemesine yol açmıştı.
///
/// Kontroller artık motifi kendi anahtarıyla arar.
void main() {
  Widget wrap(Widget child, {bool dark = true}) {
    return MaterialApp(
      theme: dark ? AppTheme.dark() : AppTheme.light(),
      home: Scaffold(
        body: Center(child: SizedBox(width: 200, child: child)),
      ),
    );
  }

  // 2026-09-29 Şahnê: kilim deseni çubuktan kaldırıldı — Şahnê'de tek
  // sahiplenilmiş motif göz şerididir ve yalnız sahne kartının üst
  // kenarında ve sonuç puanının altında durur. Motif bekçileri yerine
  // çubuğun Şahnê sözleşmesi sabitlenir: S pah, iz Ray, dolgu rol rengi.
  testWidgets('Şahnê ilerleme çubuğu: S pah, Ray iz, öğrenme dolgusu', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(const KilimProgressBar(value: 0.6, height: 10)),
    );

    expect(find.byKey(const ValueKey('kilim-progress-track')), findsOneWidget);
    expect(find.byKey(const ValueKey('kilim-progress-fill')), findsOneWidget);
    expect(find.byKey(const ValueKey('kilim-progress-motif')), findsNothing);

    final context = tester.element(
      find.byKey(const ValueKey('kilim-progress-track')),
    );
    final t = SahneTokens.of(context);
    final track = tester.widget<Container>(
      find.byKey(const ValueKey('kilim-progress-track')),
    );
    final decoration = track.decoration! as ShapeDecoration;
    expect(decoration.color, t.s3);
    expect(decoration.shape, SahneShape.s);
    final fill = tester.widget<DecoratedBox>(
      find.descendant(
        of: find.byKey(const ValueKey('kilim-progress-fill')),
        matching: find.byType(DecoratedBox),
      ),
    );
    expect((fill.decoration as ShapeDecoration).color, t.learnBar);
  });

  testWidgets('Agir verilse de dolgu Agir olmaz (rolüne çevrilir)', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(const KilimProgressBar(value: 0.6, color: AppTheme.brand)),
    );
    final fill = tester.widget<DecoratedBox>(
      find.descendant(
        of: find.byKey(const ValueKey('kilim-progress-fill')),
        matching: find.byType(DecoratedBox),
      ),
    );
    final t = SahneTokens.of(
      tester.element(find.byKey(const ValueKey('kilim-progress-fill'))),
    );
    expect((fill.decoration as ShapeDecoration).color, t.gold);
  });

  testWidgets('renkli zeminde iz rengi dışarıdan verilebilir', (tester) async {
    // Renkli hero üzerinde tema yüzeyi (açık) iz olarak kullanılınca
    // dolgudan ayırt edilemiyor ve %0 ilerleme "tamamen dolu" gibi
    // okunuyordu — motif taşınırken oluşan regresyon (2026-07-25).
    await tester.pumpWidget(
      wrap(
        KilimProgressBar(
          value: 0,
          color: Colors.white,
          trackColor: Colors.white.withValues(alpha: 0.22),
          borderColor: Colors.white.withValues(alpha: 0.30),
        ),
      ),
    );

    final track = tester.widget<Container>(
      find.byKey(const ValueKey('kilim-progress-track')),
    );
    final decoration = track.decoration! as ShapeDecoration;
    expect(decoration.color, Colors.white.withValues(alpha: 0.22));
  });

  testWidgets('sınır değerlerde taşma ya da istisna yok', (tester) async {
    for (final value in [-1.0, 0.0, 1.0, 2.0]) {
      await tester.pumpWidget(wrap(KilimProgressBar(value: value)));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'value=$value');
    }
  });
}
