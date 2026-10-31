/// Seviye belirleme sınavının saf (UI'dan bağımsız) puanlama mantığı.
///
/// Zorluk-ağırlıklı bir oran hesaplar: her sorunun ağırlığı kendi
/// difficulty'sidir (1-5). Kullanıcının kazandığı puan = doğru bilinen
/// soruların difficulty toplamı; olası puan = tüm soruların difficulty
/// toplamı. Oran, açıklanabilir eşiklerle üç seviyeye eşlenir.
///
/// Cevaplanmayan sorular yanlış sayılır (puan kazanılmaz) ancak
/// [totalQuestions] verilirse toplam soru sayısına dahil edilir.
library;

import 'dart:math';

import '../models/question_metadata.dart';
import '../models/quiz_question.dart';
import 'question_content_policy.dart';
import 'question_set_policy.dart';

enum PlacementLevel {
  destpek,
  navin,
  pesketi;

  String get labelKu => switch (this) {
    PlacementLevel.destpek => 'Destpêk',
    PlacementLevel.navin => 'Navîn',
    PlacementLevel.pesketi => 'Pêşketî',
  };

  String get labelTr => switch (this) {
    PlacementLevel.destpek => 'Başlangıç',
    PlacementLevel.navin => 'Orta',
    PlacementLevel.pesketi => 'İleri',
  };

  /// Kalıcı depolama için kararlı anahtar.
  String get storageKey => name;

  static PlacementLevel? fromStorageKey(String? key) {
    for (final level in PlacementLevel.values) {
      if (level.name == key) return level;
    }
    return null;
  }
}

/// Tek bir seviye sorusunun sonucu.
class PlacementItem {
  const PlacementItem({required this.difficulty, required this.correct});

  final int difficulty;
  final bool correct;
}

class PlacementResult {
  const PlacementResult({
    required this.level,
    required this.correctCount,
    required this.totalCount,
    required this.weightedRatio,
  });

  final PlacementLevel level;
  final int correctCount;
  final int totalCount;
  final double weightedRatio;
}

class PlacementScoring {
  const PlacementScoring._();

  /// 0.40'ın altı Başlangıç, 0.75'in altı Orta, üstü İleri.
  static const double navinThreshold = 0.40;
  static const double pesketiThreshold = 0.75;

  static PlacementResult evaluate(
    List<PlacementItem> answers, {
    int? totalQuestions,
  }) {
    final requestedTotal = totalQuestions ?? answers.length;
    if (answers.isEmpty || requestedTotal <= 0) {
      return PlacementResult(
        level: PlacementLevel.destpek,
        correctCount: 0,
        totalCount: max(0, requestedTotal),
        weightedRatio: 0,
      );
    }

    final total = max(requestedTotal, answers.length);

    // Zorluğu 1-5 aralığına sıkıştır; bilinmeyen/yanlış değerleri normalize et.
    int clampDifficulty(int d) => d.clamp(1, 5);

    double possible = 0;
    double earned = 0;
    int correctCount = 0;
    for (final a in answers) {
      final w = clampDifficulty(a.difficulty).toDouble();
      possible += w;
      if (a.correct) {
        earned += w;
        correctCount += 1;
      }
    }

    // Cevaplanmayan sorular ortalama-ağırlıkla olası puana eklenir (yanlış).
    final unanswered = total - answers.length;
    if (unanswered > 0) {
      final avgWeight = possible / answers.length;
      possible += avgWeight * unanswered;
    }

    final ratio = possible > 0 ? earned / possible : 0.0;

    final PlacementLevel level;
    if (ratio >= pesketiThreshold) {
      level = PlacementLevel.pesketi;
    } else if (ratio >= navinThreshold) {
      level = PlacementLevel.navin;
    } else {
      level = PlacementLevel.destpek;
    }

    return PlacementResult(
      level: level,
      correctCount: correctCount,
      totalCount: total,
      weightedRatio: ratio,
    );
  }

  // Ders etiketi olmayan, kökü ve seçenekleriyle dil becerisi ölçtüğü
  // incelenmiş ek maddeler. Bankanın onayı, zorluğu ve oynanabilirlik
  // denetimi bunlarda da geçerlidir.
  static const _additionalLanguageItems = {
    'edit_ziman_0004', // İzafe ile isim bağlama
    'edit_ziman_0025', // Belirsizlik eki
    'edit_ziman_0029', // Yer bildiren yapım eki
    'edit_ziman_0040', // Örnek cümlede zamanı tanıma
    'edit_ziman_0049', // Sözcüğü kök ve eke ayırma
    'edit_ziman_0027', // Geçişli geçmişte fiil uyumu
    'edit_ziman_0042', // Emir kipini tanıma
    'edit_ziman_0044', // İzafede cinsiyet ayrımı
    'ds_ziman_1229', // İki örnekte nesneye göre kişi eki
    'ds_ziman_1232', // Geçişli/geçişsiz fiillerin önceki geçmiş çekimi
    'ds_ziman_1234', // Olumsuz geçmişte fiil ve zamir seçimi
    'ds_ziman_1246', // Yalın ve bükünlü zamirleri eşleme
    'ds_ziman_1249', // Çevre edatların anlamını ayırt etme
    'ds_ziman_1280', // Bükünlü işaret zamirleri
    'ds_ziman_1290', // İsim tamlamasında cinsiyet farkını okuma
  };

  /// Her sınav için onaylı dil hedeflerini örnekler. Aynı zorlukta
  /// seçenek varsa önceki sınavdaki kimliği veya soru kökünü tekrarlamaz.
  /// Küçük havuzlarda önce zorluk dengesini korur, sonra eksikleri doldurur.
  static List<QuizQuestion> selectQuestions(
    List<QuizQuestion> pool, {
    int count = 12,
    List<QuizQuestion> previous = const [],
    Random? random,
  }) {
    if (count <= 0) return const [];
    const contentPolicy = QuestionContentPolicy();
    final candidates = pool.where((q) {
      final metadata = q.metadata;
      return q.category == 'Ziman' &&
          metadata?.reviewStatus == ReviewStatus.approved &&
          ((metadata?.learningLessonId?.trim().isNotEmpty ?? false) ||
              metadata?.productiveRecallEligible == true ||
              _additionalLanguageItems.contains(q.id)) &&
          (q.type == QuestionType.multipleChoice ||
              q.type == QuestionType.trueFalse) &&
          contentPolicy.isPlayable(q);
    }).toList()..shuffle(random);

    final previousIds = previous.map((q) => q.id).toSet();
    final previousPrompts = previous
        .map((q) => QuestionSetPolicy.normalize(q.prompt))
        .toSet();
    final fresh = <QuizQuestion>[];
    final repeated = <QuizQuestion>[];
    final ids = <String>{};
    final prompts = <String>{};
    for (final q in candidates) {
      final prompt = QuestionSetPolicy.normalize(q.prompt);
      if (ids.contains(q.id) || prompts.contains(prompt)) continue;
      ids.add(q.id);
      prompts.add(prompt);
      if (previousIds.contains(q.id) || previousPrompts.contains(prompt)) {
        repeated.add(q);
      } else {
        fresh.add(q);
      }
    }

    final ordered = [...fresh, ...repeated];
    final buckets = [
      ordered.where((q) => q.difficulty <= 2),
      ordered.where((q) => q.difficulty == 3),
      ordered.where((q) => q.difficulty >= 4),
    ];
    final selected = <QuizQuestion>[
      for (var i = 0; i < buckets.length; i++)
        ...buckets[i].take(count ~/ 3 + (i < count % 3 ? 1 : 0)),
    ];
    if (selected.length < count) {
      final selectedIds = selected.map((q) => q.id).toSet();
      selected.addAll(
        ordered
            .where((q) => !selectedIds.contains(q.id))
            .take(count - selected.length),
      );
    }
    return selected;
  }

  /// Belirlenen seviyeye göre öğrenme yolunda ÖNERİLEN başlangıç düğümünün
  /// indeksi. Bu yalnızca bir öneri/işarettir: önceki dersleri "tamamlandı"
  /// YAPMAZ ve kilit durumunu değiştirmez. İleri seviye kullanıcıyı yolun
  /// ilerisine yönlendirir; başlangıç seviyesi ilk düğümü işaret eder.
  static int recommendedStartIndex(PlacementLevel? level, int lessonCount) {
    if (lessonCount <= 0) return 0;
    final last = lessonCount - 1;
    final idx = switch (level) {
      null || PlacementLevel.destpek => 0,
      PlacementLevel.navin => (lessonCount * 0.33).floor(),
      PlacementLevel.pesketi => (lessonCount * 0.66).floor(),
    };
    return idx.clamp(0, last);
  }
}
