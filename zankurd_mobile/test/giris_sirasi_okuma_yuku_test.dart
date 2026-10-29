import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/services/question_set_policy.dart';

import 'support/widget_test_helpers.dart';

/// Giriş basamaklarında (Destpêk / Bingeh) tur hafiften ağıra okunur.
///
/// ## Kusur (Codex denetimi 2026-10-29, içerik #4)
///
/// `loadLevelQuestions` havuzu okuma yüküne göre sıralıyordu ama ardından
/// `_selectFresh` -> `SeenQuestionStore.preferUnseen` görülmemişleri
/// KARIŞTIRIYORDU; sıralama seçimden sonra kayboluyor, turun ilk sorusunun
/// hafif okunması güvencesiz kalıyordu.
///
/// ## Niçin sessiz kalırdı
///
/// Sıralama testleri yalnız `byReadingLoad`ı sınıyordu, onun SEÇİMDEN SONRA
/// da geçerli kalıp kalmadığını değil.
///
/// ## Kural
///
/// Dönen turda tanıma soruları okuma yüküne göre artan sırada gelir.
void main() {
  test(
    'giriş basamağı turunda tanıma soruları okuma yüküne göre artar',
    () async {
      final repository = freshMockRepository();
      for (var run = 0; run < 6; run++) {
        final round = await repository.loadLevelQuestions(
          category: 'Ziman',
          difficultyMin: 1,
          difficultyMax: 2,
          limit: 10,
        );
        final recognition = round
            .where((q) => !QuestionSetPolicy.isProductionTask(q))
            .map(QuestionSetPolicy.readingLoad)
            .toList();
        for (var i = 1; i < recognition.length; i++) {
          expect(
            recognition[i],
            greaterThanOrEqualTo(recognition[i - 1]),
            reason: 'tur $run: $recognition',
          );
        }
      }
    },
  );
}
