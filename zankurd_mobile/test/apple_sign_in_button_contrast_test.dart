import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/providers/theme_provider.dart';
import 'package:zankurd_mobile/src/screens/sign_in_screen.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';

import 'support/widget_test_helpers.dart';

/// Apple giriş düğmesinin gövdesi arkadaki yüzeyden ayırt edilebilmeli.
///
/// ## Kusur
///
/// Düğme ilk yazıldığında yalnız Apple'ın siyah varyantı vardı: gövde sabit
/// `Colors.black`. Karanlık temada giriş kartının zemini `#181E1B` (sayfa
/// zemini `#0E1512` üzerine %4 beyaz perde) ve siyah gövde oraya **1.24:1**
/// ile oturuyordu. Yani düğmenin kendisi görünmüyor, havada duran beyaz bir
/// yazı ve elma simgesi kalıyordu (2026-08-16 ekran turu, `75_sign_in_dark`).
///
/// Yanındaki Google düğmesi tam aynı kusuru 2026-07-30'da yaşamış ve konturla
/// çözülmüştü; Apple düğmesi o karardan sonra eklendiği için atlandı.
///
/// ## Niçin sessiz kaldı
///
/// `contrast_policy_test.dart` palet kararlarını sabitler, ekranların tek tek
/// düğmelerine bakmaz; `brand_accent_guard_test.dart` ise marka dışı renk
/// arar, siyah/beyaz onun için zaten meşrudur. Düğme her iki bekçinin de
/// kör noktasına düşüyordu ve widget testleri rengi hiç ölçmüyordu.
///
/// ## Kural
///
/// Apple'ın düğme kılavuzu iki varyant tanır: açık zeminde siyah, koyu
/// zeminde beyaz. Bekçi varyantın adını değil ölçülebilir sonucunu bağlar —
/// gövde/zemin en az 3:1 (WCAG 1.4.11, metin olmayan arayüz bileşeni),
/// yazı/gövde en az 4.5:1.
double _relativeLuminance(Color c) => c.computeLuminance();

double _contrast(Color a, Color b) {
  final l1 = _relativeLuminance(a);
  final l2 = _relativeLuminance(b);
  final hi = math.max(l1, l2);
  final lo = math.min(l1, l2);
  return (hi + 0.05) / (lo + 0.05);
}

/// Yarı saydam bir rengi zemine harmanlayıp gerçekte görünen rengi verir.
Color _flatten(Color foreground, Color background) {
  final a = foreground.a;
  return Color.from(
    alpha: 1,
    red: foreground.r * a + background.r * (1 - a),
    green: foreground.g * a + background.g * (1 - a),
    blue: foreground.b * a + background.b * (1 - a),
  );
}

/// Apple düğmesinin gövde rengini çizen kutuyu bulur.
Color _appleButtonSurface(WidgetTester tester) {
  final container = tester.widget<AnimatedContainer>(
    find
        .ancestor(
          of: find.text('Apple ile giriş yap'),
          matching: find.byType(AnimatedContainer),
        )
        .first,
  );
  final decoration = container.decoration as BoxDecoration;
  return decoration.color!;
}

/// Düğme yazısının rengi — simge de aynı rengi kullanır.
Color _appleButtonLabel(WidgetTester tester) =>
    tester.widget<Text>(find.text('Apple ile giriş yap')).style!.color!;

void main() {
  for (final (name, mode) in [
    ('açık', ThemeMode.light),
    ('karanlık', ThemeMode.dark),
  ]) {
    testWidgets('$name temada Apple düğmesinin gövdesi zeminden ayrılır', (
      tester,
    ) async {
      await tester.pumpWidget(
        testShell(
          child: const SignInScreen(),
          themeProvider: ThemeProvider(initialMode: mode),
        ),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(SignInScreen));
      final page = AppTheme.bgOf(context);
      // Kart, sayfa zemininin üstünde ince bir perde; düğme ikisinin
      // birleşiminin üstüne düşüyor. Perdeyi harmanlayıp gerçek zemini alırız.
      final panel = AppTheme.isLight(context)
          ? AppTheme.lightSurface
          : _flatten(Colors.white.withValues(alpha: 0.04), page);

      final surface = _appleButtonSurface(tester);
      expect(
        _contrast(surface, panel),
        greaterThanOrEqualTo(3.0),
        reason:
            '$name temada Apple düğmesinin gövdesi kart zemininden '
            'ayırt edilemiyor.',
      );

      expect(
        _contrast(_appleButtonLabel(tester), surface),
        greaterThanOrEqualTo(4.5),
        reason: '$name temada Apple düğmesinin yazısı gövdesinde okunmuyor.',
      );
    });
  }
}
