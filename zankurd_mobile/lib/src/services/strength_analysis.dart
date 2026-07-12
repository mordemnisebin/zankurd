/// Kişisel "Güçlü ve Geliştirilecek Alanlar" haritasının saf analiz çekirdeği.
///
/// UI'dan ve store'lardan bağımsızdır: yalnız ham sayıları alır, açıklanabilir
/// skorlar üretir. Az veri varsa kesin yargı üretmez ([insufficientData]).
/// Olumsuz dil kullanılmaz; ton [InsightTone] ile ikon+metin olarak sunulur
/// (renk tek başına anlam taşımaz).
library;

enum InsightTone { strength, improve, neutral }

class CategoryInsight {
  const CategoryInsight({
    required this.category,
    required this.correct,
    required this.mistakes,
    required this.readyReviews,
    required this.score,
    required this.tone,
  });

  final String category;

  /// MasteryStore doğru sayısı.
  final int correct;
  final int mistakes;
  final int readyReviews;

  /// Geliştirme skoru: yüksek = daha çok ilgi gerekir. Açıklanabilir formül.
  final double score;
  final InsightTone tone;
}

class StrengthMapResult {
  const StrengthMapResult({
    required this.insufficientData,
    required this.strengths,
    required this.improvements,
    required this.focusCategory,
  });

  final bool insufficientData;

  /// En güçlü kategoriler (skor küçükten büyüğe, güçlü olanlar).
  final List<CategoryInsight> strengths;

  /// En çok geliştirilecek kategoriler (skor büyükten küçüğe).
  final List<CategoryInsight> improvements;

  /// Zana günlük hedefinin yönlendirilebileceği tek kategori (varsa hazır
  /// tekrarı olan öncelikli, yoksa en yüksek skorlu).
  final String? focusCategory;
}

class StrengthAnalysis {
  const StrengthAnalysis._();

  /// Bir kategoriyi "güçlü" saymak için gereken en az doğru sayısı
  /// (Mastery: Xwendekar eşiği).
  static const int strengthCorrectThreshold = 20;

  static StrengthMapResult analyze({
    required List<String> categories,
    required Map<String, int> masteryCorrect,
    required Map<String, int> mistakes,
    Map<String, int> readyReviews = const {},
    int minTotalData = 5,
  }) {
    int totalCorrect = 0;
    int totalMistakes = 0;
    for (final c in categories) {
      totalCorrect += masteryCorrect[c] ?? 0;
      totalMistakes += mistakes[c] ?? 0;
    }

    if (totalCorrect + totalMistakes < minTotalData) {
      return const StrengthMapResult(
        insufficientData: true,
        strengths: [],
        improvements: [],
        focusCategory: null,
      );
    }

    final insights = <CategoryInsight>[];
    for (final c in categories) {
      final correct = masteryCorrect[c] ?? 0;
      final mist = mistakes[c] ?? 0;
      final ready = readyReviews[c] ?? 0;
      // Veri yoksa kategoriyi haritaya katma (kesin yargı üretme).
      if (correct == 0 && mist == 0 && ready == 0) continue;

      // Açıklanabilir skor: hatalar ağır, mastery açığı hafif katkı yapar.
      final masteryDeficit = (100 - correct.clamp(0, 100)).toDouble();
      final score = mist * 2.0 + masteryDeficit / 5.0;

      final InsightTone tone;
      if (correct >= strengthCorrectThreshold && mist <= correct ~/ 4) {
        tone = InsightTone.strength;
      } else if (mist >= 3 || correct < strengthCorrectThreshold) {
        tone = InsightTone.improve;
      } else {
        tone = InsightTone.neutral;
      }

      insights.add(
        CategoryInsight(
          category: c,
          correct: correct,
          mistakes: mist,
          readyReviews: ready,
          score: score,
          tone: tone,
        ),
      );
    }

    final strengths =
        insights.where((i) => i.tone == InsightTone.strength).toList()
          ..sort((a, b) => a.score.compareTo(b.score));
    final improvements =
        insights.where((i) => i.tone == InsightTone.improve).toList()
          ..sort((a, b) {
            final c = b.score.compareTo(a.score);
            return c != 0 ? c : a.category.compareTo(b.category);
          });

    // Odak: önce hazır tekrarı olanlar (en yüksek skorlu), yoksa genel en
    // yüksek skorlu geliştirme kategorisi.
    String? focus;
    final withReviews = insights.where((i) => i.readyReviews > 0).toList()
      ..sort((a, b) => b.score.compareTo(a.score));
    if (withReviews.isNotEmpty) {
      focus = withReviews.first.category;
    } else if (improvements.isNotEmpty) {
      focus = improvements.first.category;
    }

    return StrengthMapResult(
      insufficientData: false,
      strengths: strengths,
      improvements: improvements,
      focusCategory: focus,
    );
  }
}
