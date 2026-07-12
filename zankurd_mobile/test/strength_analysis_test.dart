import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/services/strength_analysis.dart';

void main() {
  const cats = ['Ziman', 'Dîrok', 'Çand', 'Muzîk'];

  test('hiç veri yok → insufficientData, yargı üretmez', () {
    final r = StrengthAnalysis.analyze(
      categories: cats,
      masteryCorrect: const {},
      mistakes: const {},
    );
    expect(r.insufficientData, isTrue);
    expect(r.strengths, isEmpty);
    expect(r.improvements, isEmpty);
    expect(r.focusCategory, isNull);
  });

  test('tek kategori yoğun hata → improvements + focus o kategori', () {
    final r = StrengthAnalysis.analyze(
      categories: cats,
      masteryCorrect: const {'Ziman': 30},
      mistakes: const {'Dîrok': 8},
    );
    expect(r.insufficientData, isFalse);
    expect(r.improvements.any((i) => i.category == 'Dîrok'), isTrue);
    expect(r.focusCategory, 'Dîrok');
  });

  test('yüksek mastery + düşük hata → strength', () {
    final r = StrengthAnalysis.analyze(
      categories: cats,
      masteryCorrect: const {'Ziman': 120},
      mistakes: const {'Ziman': 1},
    );
    expect(r.strengths.any((i) => i.category == 'Ziman'), isTrue);
    expect(
      r.strengths.firstWhere((i) => i.category == 'Ziman').tone,
      InsightTone.strength,
    );
  });

  test('eşit kategoriler deterministik sıralanır', () {
    final r = StrengthAnalysis.analyze(
      categories: cats,
      masteryCorrect: const {},
      mistakes: const {'Ziman': 5, 'Dîrok': 5},
    );
    // Eşit skorda kararlı (Unicode) sıra: 'Dîrok'(D) < 'Ziman'(Z).
    final imp = r.improvements.map((i) => i.category).toList();
    expect(imp.indexOf('Dîrok') < imp.indexOf('Ziman'), isTrue);
  });

  test('hazır tekrar önceliği: focus hazır tekrarı olan kategoridir', () {
    final r = StrengthAnalysis.analyze(
      categories: cats,
      masteryCorrect: const {'Ziman': 10},
      // Dîrok skoru daha yüksek ama Çand'da hazır tekrar var → focus Çand.
      mistakes: const {'Dîrok': 10, 'Çand': 2},
      readyReviews: const {'Çand': 4},
    );
    expect(r.focusCategory, 'Çand');
  });

  test('veri olmayan kategori haritaya katılmaz', () {
    final r = StrengthAnalysis.analyze(
      categories: cats,
      masteryCorrect: const {'Ziman': 40},
      mistakes: const {'Ziman': 2},
    );
    final all = [...r.strengths, ...r.improvements].map((i) => i.category);
    expect(all.contains('Muzîk'), isFalse);
  });
}
