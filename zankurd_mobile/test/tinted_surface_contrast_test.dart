import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';

/// Tonlu kart zemininde metin okunabilirliği.
///
/// 2026-07-27: turnuva giriş kartının ipucu satırı koyu temada ekran
/// görüntüsünden ölçüldüğünde 3.38:1 çıktı — AA eşiği olan 4.5:1'in
/// altında. Renkler temadan geliyordu ve kod doğru görünüyordu; kusur
/// **zeminin başka bir zemin olmasıydı**. `textSubColor` ve
/// `textMutedColor` düz yüzeye (#18211B) göre seçilmiştir, oysa bu kart
/// yüzeyin üstüne altın tonu serer ve gerçek zemin belirgin biçimde
/// açılır. Yüzeye karşı ölçen bir bekçi bu kusuru göremezdi.
///
/// Bu yüzden test, kartın katmanlarını (yüzey → altın gradyan → altın
/// parıltı) gerçekten harmanlar ve metni **o** renge karşı ölçer.
double _contrast(Color a, Color b) {
  final hi = math.max(a.computeLuminance(), b.computeLuminance());
  final lo = math.min(a.computeLuminance(), b.computeLuminance());
  return (hi + 0.05) / (lo + 0.05);
}

Color _over(Color foreground, Color background) {
  final a = foreground.a;
  return Color.from(
    alpha: 1,
    red: foreground.r * a + background.r * (1 - a),
    green: foreground.g * a + background.g * (1 - a),
    blue: foreground.b * a + background.b * (1 - a),
  );
}

/// `tournament_screen.dart` içindeki kart katmanlarının aynısı.
Color _tintedCard(Color surface) {
  var color = _over(AppTheme.gold.withValues(alpha: 0.18), surface);
  return _over(AppTheme.gold.withValues(alpha: 0.07), color);
}

/// Tonal düğmenin zemini: aksan@0.14 yüzeyin üstünde.
Color _tonalButton(Color accent, Color surface) =>
    _over(accent.withValues(alpha: 0.14), surface);

void main() {
  testWidgets('tonal düğme etiketi kendi zemininde okunur', (tester) async {
    // 2026-07-27: arkadaş kartındaki "Odaya çağır" düğmesi ham aksanı
    // (#2F6F62) yazı rengi olarak kullanıyordu; koyu temada kendi tonlu
    // zemininde 2.49:1 ölçüldü. Düğme etkin olduğu hâlde kapalı görünüyordu
    // — sessiz bir kusur: kod doğru, renk kararı yanlıştı.
    for (final (label, theme, surface) in [
      ('koyu', AppTheme.dark(), AppTheme.surface),
      ('açık', AppTheme.light(), AppTheme.lightSurface),
    ]) {
      final labels = <String, Color>{};
      for (final (name, accent) in [
        ('cyan', AppTheme.cyan),
        ('altın', AppTheme.gold),
        ('marka', AppTheme.brand),
        // Cevap dökümündeki "DOĞRU"/"YANLIŞ" şeritleri aynı kalıbı
        // kullanıyordu: 2.59:1 ve 3.13:1 (2026-07-27).
        ('doğru', AppTheme.correct),
        ('yanlış', AppTheme.wrong),
      ]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Builder(
              builder: (c) {
                labels[name] = AppColors.onAccentTint(c, accent);
                return const SizedBox();
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          _contrast(labels[name]!, _tonalButton(accent, surface)),
          greaterThanOrEqualTo(4.5),
          reason: '$label temada $name tonal düğmenin etiketi okunmuyor',
        );
      }
    }
  });

  test('dolu düğmenin etiketi zemine göre seçilir', () {
    // 2026-07-27: dolu düğmelerde yazı rengi sabit beyazdı. Beyaz koyu
    // aksanlarda doğru, açık aksanlarda değil — "Flaş kart" altın zeminde
    // 2.30:1, "Dersler" orta yeşilde 3.96:1 ölçüldü. Etiket zeminde
    // eriyordu ve tasarım kararı gibi görünüyordu.
    for (final (name, background) in [
      ('altın', AppTheme.gold),
      ('orta yeşil', AppTheme.playGreen),
      ('cyan', AppTheme.cyan),
      ('marka', AppTheme.brand),
      ('doğru', AppTheme.correct),
    ]) {
      expect(
        _contrast(AppColors.onSolid(background), background),
        greaterThanOrEqualTo(4.5),
        reason: '$name zeminde dolu düğme etiketi okunmuyor',
      );
    }
  });

  testWidgets('tonlu kart üzerindeki metinler AA eşiğini geçer', (
    tester,
  ) async {
    for (final (label, theme, surface) in [
      ('koyu', AppTheme.dark(), AppTheme.surface),
      ('açık', AppTheme.light(), AppTheme.lightSurface),
    ]) {
      // Renkler ağacın **içinde** okunur: dışarıda okunursa yakalanan
      // context bir önceki temanın olabilir ve test sessizce yanlış
      // temayı ölçer. Aynı sebeple aşağıda `pumpAndSettle` var —
      // `MaterialApp` tema değişimini `AnimatedTheme` ile yumuşatır ve tek
      // kare sonra tema hâlâ bir öncekine yakındır; ilk yazımda açık tema
      // turu koyu temanın renklerini ölçüyordu.
      late Color primary;
      late Color secondary;
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Builder(
            builder: (c) {
              primary = AppColors.onTintedSurface(c);
              secondary = AppColors.onTintedSurface(c, secondary: true);
              return const SizedBox();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      final background = _tintedCard(surface);
      for (final (name, color) in [
        ('birincil', primary),
        ('ikincil', secondary),
      ]) {
        expect(
          _contrast(color, background),
          greaterThanOrEqualTo(4.5),
          reason: '$label temada $name metin tonlu kart üzerinde okunmuyor',
        );
      }
    }
  });
}
