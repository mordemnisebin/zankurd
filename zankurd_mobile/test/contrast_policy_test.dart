import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';

/// 2026-07-22 canlı UX denetimi (P1-A): renkli zeminlerin üzerine aynı renk
/// ailesinden metin konması beş ayrı ekranda tekrar ediyordu — profil
/// "Bronz Lig" rozeti, sonuç ekranı yıldız + istatistik etiketleri, çark
/// kutlama bandı, turnuva çipi, kategori kartı alt metni.
///
/// Bu testler düzeltmelerin ardındaki renk kararlarını sabitler.
double _luminance(Color c) => c.computeLuminance();

double contrastRatio(Color a, Color b) {
  final l1 = _luminance(a);
  final l2 = _luminance(b);
  final hi = math.max(l1, l2);
  final lo = math.min(l1, l2);
  return (hi + 0.05) / (lo + 0.05);
}

/// [foreground]'ı [background] üzerine alfa harmanlayarak gerçek rengi bulur.
Color _flatten(Color foreground, Color background) {
  final a = foreground.a;
  return Color.from(
    alpha: 1,
    red: foreground.r * a + background.r * (1 - a),
    green: foreground.g * a + background.g * (1 - a),
    blue: foreground.b * a + background.b * (1 - a),
  );
}

void main() {
  group('renkli zemin üzerinde okunabilirlik', () {
    test('eylem turuncusu beyaz metinle tek başına AA geçer', () {
      // 2026-07-24: eski #F5931E beyazla yalnız ~2.2:1 veriyordu ve her CTA
      // karartma perdesine muhtaçtı. Tîrêj (#C2560E) perdesiz geçer — palet
      // düzeltildiği için yama gereksizleşti. Gradyanın her iki ucu da geçmeli.
      for (final background in [
        AppTheme.brand,
        AppTheme.brandDeep,
        AppTheme.primaryGradientStart,
      ]) {
        expect(
          contrastRatio(Colors.white, background),
          greaterThanOrEqualTo(4.5),
          reason: 'zemin $background',
        );
      }
    });

    test('heroScrim eklenince beyaz metin AA eşiğini geçer', () {
      // Hem açık turuncu (gradyan başı) hem koyu turuncu (profil hero'su)
      // üzerinde eşiğin üstünde kalmalı.
      for (final background in [
        AppTheme.primaryGradientStart,
        AppTheme.brandDeep,
      ]) {
        final scrim = _flatten(AppColors.heroScrim(), background);
        expect(
          contrastRatio(Colors.white, scrim),
          greaterThanOrEqualTo(4.5),
          reason: 'zemin $background',
        );
      }
    });

    test('altın bant üzerinde koyu mürekkep AA eşiğini geçer', () {
      expect(
        contrastRatio(AppTheme.bg, AppTheme.gold),
        greaterThanOrEqualTo(4.5),
      );
      // Eski hâli (beyaz) geçmiyordu.
      expect(contrastRatio(Colors.white, AppTheme.gold), lessThan(3));
    });
  });

  group('AppColors.readableAccent', () {
    testWidgets('açık temada açık aksanı okunabilir açıklığa çeker', (
      tester,
    ) async {
      late Color adapted;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Builder(
            builder: (context) {
              adapted = AppColors.readableAccent(context, AppTheme.gold);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(
        contrastRatio(adapted, AppTheme.lightSurface),
        greaterThanOrEqualTo(4.5),
        reason: 'altın aksan açık yüzeyde okunabilir olmalı',
      );
      // Aksan kimliği korunmalı: ton kayması olmamalı.
      expect(
        HSLColor.fromColor(adapted).hue,
        closeTo(HSLColor.fromColor(AppTheme.gold).hue, 1),
      );
    });

    testWidgets('koyu temada aksan olduğu gibi kalır veya aydınlatılır', (
      tester,
    ) async {
      late Color adapted;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          home: Builder(
            builder: (context) {
              adapted = AppColors.readableAccent(context, AppTheme.gold);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(
        contrastRatio(adapted, AppTheme.surface),
        greaterThanOrEqualTo(4.5),
      );
    });
  });

  /// 2026-08-02 denetimi (A-02 -> P2-010): quiz şık kartlarının cevap
  /// durumları bu politikanın DIŞINDA kalmıştı. `contrast_policy_test`
  /// marka turuncusunu, heroScrim'i ve altın bandı ölçüyordu;
  /// `quiz_accent_test` gradyanlara dokunuyordu ama yalnız renk KİMLİĞİNİ
  /// doğruluyordu, kontrastı değil. Sonuç: uygulamanın en çok görüntülenen
  /// yüzeyinde beyaz metin doğru cevapta 2.97:1, yanlış cevapta 3.73:1
  /// veriyordu — ikisi de AA'nın altında, biri 3:1'in bile altında.
  ///
  /// Etiket `fontSize: isCompact ? 15 : 17`, `FontWeight.w800`
  /// (`quiz_option_tile.dart`). WCAG'ın kalın "büyük metin" eşiği
  /// 14pt = 18.67px olduğundan 17px bunun ALTINDADIR ve normal metin
  /// eşiği (4.5:1) geçerlidir. Testler bu yüzden 4.5'i kullanır.
  group('quiz cevap durumları beyaz metni okutuyor', () {
    const stops = <String, Color>{
      'doğru gradyan başlangıcı': AppTheme.correctGradientStart,
      'doğru gradyan bitişi': AppTheme.correctGradientEnd,
      'yanlış gradyan başlangıcı': AppTheme.wrongGradientStart,
      'yanlış gradyan bitişi': AppTheme.wrongGradientEnd,
    };

    for (final entry in stops.entries) {
      test('${entry.key} AA eşiğini geçer', () {
        expect(
          contrastRatio(Colors.white, entry.value),
          greaterThanOrEqualTo(4.5),
          reason:
              '${entry.key} üzerinde beyaz metin normal metin eşiğini '
              'geçmeli; şık etiketi büyük metin sayılmaz (17px < 18.67px).',
        );
      });
    }

    test('gradyanın her ara noktası da eşiği geçer', () {
      // Metin gradyanın ortasında durur; yalnız uçları ölçmek yetmez.
      for (final pair in <List<Color>>[
        [AppTheme.correctGradientStart, AppTheme.correctGradientEnd],
        [AppTheme.wrongGradientStart, AppTheme.wrongGradientEnd],
      ]) {
        for (var i = 0; i <= 10; i++) {
          final blended = Color.lerp(pair.first, pair.last, i / 10)!;
          expect(
            contrastRatio(Colors.white, blended),
            greaterThanOrEqualTo(4.5),
            reason: 'gradyan %${i * 10} noktası AA altında',
          );
        }
      }
    });

    test('gradyan hâlâ görünür bir derinlik taşıyor', () {
      // Kontrastı düzeltmek için iki durağı aynı yapmak kolay kaçıştır;
      // o zaman kart düz renge döner. Duraklar ayrık kalmalı.
      for (final pair in <List<Color>>[
        [AppTheme.correctGradientStart, AppTheme.correctGradientEnd],
        [AppTheme.wrongGradientStart, AppTheme.wrongGradientEnd],
      ]) {
        final delta =
            (pair.first.computeLuminance() - pair.last.computeLuminance())
                .abs();
        expect(delta, greaterThan(0.01), reason: 'gradyan neredeyse düz');
      }
    });

    test('gradyanlar quiz kartlarında gerçekten kullanılıyor', () {
      expect(AppTheme.correctGradient.colors, <Color>[
        AppTheme.correctGradientStart,
        AppTheme.correctGradientEnd,
      ]);
      expect(AppTheme.wrongGradient.colors, <Color>[
        AppTheme.wrongGradientStart,
        AppTheme.wrongGradientEnd,
      ]);
    });
  });
}
