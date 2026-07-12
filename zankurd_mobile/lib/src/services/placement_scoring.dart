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

import '../models/quiz_question.dart';

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
    final int total = totalQuestions ?? answers.length;
    if (answers.isEmpty || total <= 0) {
      return PlacementResult(
        level: PlacementLevel.destpek,
        correctCount: 0,
        totalCount: total < 0 ? 0 : total,
        weightedRatio: 0,
      );
    }

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
    final int unanswered = (total - answers.length).clamp(0, total);
    if (unanswered > 0) {
      final avgWeight = answers.isEmpty ? 1.0 : possible / answers.length;
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

  /// Havuzdan kolay/orta/zor dengeli bir sınav seti seçer.
  ///
  /// Deterministiktir (havuz sırasına saygı duyar); kolay(1-2), orta(3),
  /// zor(4-5) kovalarından eşit paylara yakın çeker. Bir kova yetersizse
  /// kalanı diğer kovalardan doldurur. Görsel/eksik şıklı sorular elenir.
  static List<QuizQuestion> selectQuestions(
    List<QuizQuestion> pool, {
    int count = 12,
  }) {
    final usable = pool
        .where((q) => q.answers.length >= 2 && q.correctAnswer.isNotEmpty)
        .toList();
    if (usable.length <= count) return usable;

    final easy = usable.where((q) => q.difficulty <= 2).toList();
    final medium = usable.where((q) => q.difficulty == 3).toList();
    final hard = usable.where((q) => q.difficulty >= 4).toList();

    final perBucket = (count / 3).ceil();
    final selected = <QuizQuestion>[];
    final seen = <String>{};

    void take(List<QuizQuestion> bucket, int n) {
      for (final q in bucket) {
        if (selected.length >= count) break;
        if (n <= 0) break;
        if (seen.add(q.id)) {
          selected.add(q);
          n--;
        }
      }
    }

    take(easy, perBucket);
    take(medium, perBucket);
    take(hard, perBucket);

    // Eksik kalırsa (bir kova zayıfsa) kalan havuzdan tamamla.
    if (selected.length < count) {
      for (final q in usable) {
        if (selected.length >= count) break;
        if (seen.add(q.id)) selected.add(q);
      }
    }

    return selected.take(count).toList();
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
