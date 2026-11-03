import 'dart:math' as math;

import '../data/mistake_store.dart';
import '../data/streak_store.dart';
import '../models/quiz_question.dart';

/// Ücretsiz "Seriyi kurtar" turunun saf kuralları (arayüzsüz, testlenir).
///
/// ## Niçin ayrı bir yol
///
/// Ücretli onarım (jeton, ayda bir) sunucuda; bu tur ise yalnız cihazda ve
/// tekrar alışkanlığını ödüllendirir: 24 saat içinde 5 soruyu çözüp en az 4
/// doğru yapan seriyi geri alır. Çifte sayım yok: onarılan gün `frozenDays`e
/// yazılır (ilerleme eşitlemesiyle birleşir), böylece ücretli onarım ya da
/// ikinci bir kurtarma aynı kırılmaya uygulanamaz (`rescueOffer` /
/// `repairOffer` o gün için null döner).
class StreakRescueService {
  const StreakRescueService._();

  /// Tur soruları: önce yanlış defterinin vadesi gelmişleri (en gecikmiş
  /// başta), eksik kalırsa oynanabilir bankadan rastgele; hiçbir yolda
  /// tekrarlanan soru yok. [StreakStore.rescueQuestions] kadar soru
  /// çıkmıyorsa boş liste döner (tur açılmaz).
  static List<QuizQuestion> pickQuestions({
    required MistakeStore mistakeStore,
    required List<QuizQuestion> playable,
    math.Random? random,
  }) {
    final byId = {for (final q in playable) q.id: q};
    final picked = <QuizQuestion>[
      for (final id in mistakeStore.readyIdsMostOverdueFirst)
        if (byId[id] != null) byId[id]!,
    ].take(StreakStore.rescueQuestions).toList();
    if (picked.length < StreakStore.rescueQuestions) {
      final used = {for (final q in picked) q.id};
      final rest = [
        for (final q in playable)
          if (!used.contains(q.id)) q,
      ]..shuffle(random);
      picked.addAll(rest.take(StreakStore.rescueQuestions - picked.length));
    }
    return picked.length == StreakStore.rescueQuestions
        ? picked
        : const <QuizQuestion>[];
  }

  /// Tur sonucu seriyi kurtarır mı? [completed] QuizScreen'in tamamlanma
  /// işareti (yarıda çıkış null döner).
  static bool passes({required bool completed, required int correct}) =>
      completed && correct >= StreakStore.rescueMinCorrect;
}
