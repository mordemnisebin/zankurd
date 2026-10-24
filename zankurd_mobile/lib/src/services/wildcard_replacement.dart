import '../config/subcategory_config.dart';
import '../models/quiz_question.dart';

/// "Soru değiştir" jokerinin yedek soru adayları.
///
/// ## Kusur
///
/// Joker kategorideki herhangi bir kullanılmamış soruyu çekiyordu: "Rêziman"
/// 3. soruda 30 jeton ödeyen oyuncu bir boşluk doldurma yerine tarih sorusu,
/// bir ders testinde başka dersin sorusunu alıyordu.
///
/// ## Kural
///
/// Önce aynı kapsam (ders kimliği, yoksa alt konu) ve AYNI soru türü, önce aynı
/// zorlukta; sonra zorluk serbest. Bunlardan hiçbiri yoksa eski davranışa
/// (aynı kategori) düşülür: joker ödenmiş jetonla boş dönmemeli.
List<QuizQuestion> wildcardReplacementCandidates({
  required QuizQuestion current,
  required Iterable<QuizQuestion> pool,
  required Set<String> usedIds,
  required bool Function(QuizQuestion) usable,
}) {
  bool base(QuizQuestion q) =>
      q.category == current.category && !usedIds.contains(q.id) && usable(q);
  final lessonId = current.metadata?.learningLessonId;
  final subId = SubcategoryConfig.getSubcategoryId(current);
  bool sameScope(QuizQuestion q) {
    if (lessonId != null) return q.metadata?.learningLessonId == lessonId;
    if (subId.isEmpty) return true;
    return SubcategoryConfig.getSubcategoryId(q) == subId;
  }

  final scoped = pool
      .where((q) => base(q) && q.type == current.type && sameScope(q))
      .toList(growable: false);
  final sameDifficulty = scoped
      .where((q) => q.difficulty == current.difficulty)
      .toList(growable: false);
  if (sameDifficulty.isNotEmpty) return sameDifficulty;
  if (scoped.isNotEmpty) return scoped;

  final categoryOnly = pool.where(base).toList(growable: false);
  final byDifficulty = categoryOnly
      .where((q) => q.difficulty == current.difficulty)
      .toList(growable: false);
  return byDifficulty.isNotEmpty ? byDifficulty : categoryOnly;
}
