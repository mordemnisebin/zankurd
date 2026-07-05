import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/screens/quiz/quiz_effects.dart';

void main() {
  group('comboTierFor', () {
    test('2 ve altı seri rozet üretmez', () {
      expect(comboTierFor(0), isNull);
      expect(comboTierFor(1), isNull);
      expect(comboTierFor(2), isNull);
    });

    test('3-4 seri turuncu (bronze) kademe', () {
      expect(comboTierFor(3), ComboTier.bronze);
      expect(comboTierFor(4), ComboTier.bronze);
    });

    test('5-9 seri mor (silver) kademe', () {
      expect(comboTierFor(5), ComboTier.silver);
      expect(comboTierFor(9), ComboTier.silver);
    });

    test('10+ seri altın (gold) kademe', () {
      expect(comboTierFor(10), ComboTier.gold);
      expect(comboTierFor(25), ComboTier.gold);
    });
  });

  group('vignetteStrengthFor', () {
    test('kalan süre üçte birden fazlayken vinyet yok', () {
      expect(vignetteStrengthFor(1.0), 0.0);
      expect(vignetteStrengthFor(0.5), 0.0);
      expect(vignetteStrengthFor(0.34), 0.0);
    });

    test('son üçte birde doğrusal olarak güçlenir', () {
      expect(vignetteStrengthFor(1 / 3), closeTo(0.0, 0.001));
      expect(vignetteStrengthFor(1 / 6), closeTo(0.5, 0.01));
      expect(vignetteStrengthFor(0.0), closeTo(1.0, 0.001));
    });

    test('aralık dışı girdiler kırpılır', () {
      expect(vignetteStrengthFor(-0.2), 1.0);
      expect(vignetteStrengthFor(1.7), 0.0);
    });
  });
}
