import '../models/learning_goal.dart';
import '../services/content_quality_policy.dart';
import '../models/quiz_question.dart';

const _cultureCategories = <String>{'Çand', 'Dîrok', 'Edebiyat', 'Cografya'};

/// Günlük soru havuzunda kullanıcının öğrenme amacına uyan soruları öne alır.
///
/// [candidates] zaten günlük depo tarafından sıralanmış havuzdur; bu yardımcı
/// o sırayı gruplar içinde korur. Öncelikli havuz [limit] kadar değilse kalan
/// sorularla tamamlar, böylece küçük veya geçici olarak eksik kategori havuzu
/// günlük turu gereksiz yere kısaltmaz.
List<QuizQuestion> selectDailyQuestionsForGoal({
  required List<QuizQuestion> candidates,
  required LearningGoal? goal,
  required int limit,
  int? maxDifficulty,
}) {
  if (limit <= 0 || candidates.isEmpty) return const [];

  // İlk oturum (sıfırdan başlayan kullanıcı): zorluk üst sınırı. Seçim bütün
  // zorluklardan yapıldığından ilk soruda ileri bilgiyle karşılaşılabiliyordu
  // (Codex denetimi 2026-10-29). Sınırı aşanlar yalnız yeterli kolay soru
  // yoksa, KOLAYDAN ZORA sıralı olarak turu doldurur.
  if (maxDifficulty != null) {
    final easy = candidates
        .where((question) => question.difficulty <= maxDifficulty)
        .toList(growable: false);
    final hard =
        candidates
            .where((question) => question.difficulty > maxDifficulty)
            .toList()
          ..sort((a, b) => a.difficulty.compareTo(b.difficulty));
    return selectDailyQuestionsForGoal(
      candidates: [...easy, ...hard],
      goal: goal,
      limit: limit,
    );
  }

  // Öğrenme yolunun kaynağı doğrulanmış içerikten oluşsun. İlk sürümlerde
  // metadata taşımayan eski bankalar bulunduğu için onaylı havuz günlük
  // turu doldurmaya yetmiyorsa deterministik aday sırasına geri dönülür;
  // bu, kullanıcıyı boş quiz ile bırakmadan editoryal borcu görünür tutar.
  const approvedPolicy = ContentQualityPolicy(requireApproved: true);
  final approvedCandidates = candidates
      .where((question) => approvedPolicy.isEligible(question.metadata))
      .toList(growable: false);
  final source = approvedCandidates.length >= limit
      ? approvedCandidates
      : candidates;

  final prioritized = <QuizQuestion>[];
  final fallback = <QuizQuestion>[];

  for (final question in source) {
    final isPriority = switch (goal) {
      LearningGoal.learnKurmanci => question.category == 'Ziman',
      LearningGoal.discoverCulture => _cultureCategories.contains(
        question.category,
      ),
      null => false,
    };
    (isPriority ? prioritized : fallback).add(question);
  }

  return [...prioritized, ...fallback].take(limit).toList(growable: false);
}
