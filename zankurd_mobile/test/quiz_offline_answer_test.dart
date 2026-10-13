import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/offline_zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/room.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/screens/quiz_screen.dart';
import 'package:zankurd_mobile/src/widgets/sahne/sahne.dart';

import 'support/widget_test_helpers.dart';

/// Çevrimdışı turda cevaptan sonra "Sonraki" beklemesi — 2026-09-30
/// simülatör (S11).
///
/// Kusur: çevrimdışı çalışan uygulamada cevap seçilince "Bidomîne/Sonraki"
/// düğmesi kum saatiyle 4-8 sn pasif kalıyor, doğru/yanlış rengi geç
/// geliyordu; oyuncu ne beklediğini bilmiyordu. Beklemenin üst sınırı tek
/// kişilik turda bile ağ için ayrılmış 8 sn idi: bir depo cevabı geciktirirse
/// (takılan bağlantı) düğme o kadar kilitli kalırdı.
///
/// Kusur SESSİZ kaldı çünkü testler `isFlutterTestEnvironment` yüzünden hem
/// 520 ms'lik gerilim tutuşunu hem de gecikmeli depoyu hiç yaşamıyordu: sahte
/// depo hep anında dönüyordu. Bu dosya üretimdeki tutuşu (`suspenseHold`)
/// zorlar ve depoyu hiç dönmeyecek biçimde takar.
const _question = QuizQuestion(
  id: 'offline-q1',
  category: 'Ziman',
  prompt: 'Peyva «av» bi Tirkî çi tê gotin?',
  answers: ['su', 'ekmek', 'yol', 'dağ'],
  correctAnswer: 'su',
  explanation: '«av» Türkçede «su» demektir.',
);

/// Hiç cevap vermeyen depo: bağlantı takılmış.
class _HangingRepository extends OfflineZanKurdRepository {
  @override
  Future<Map<String, dynamic>> submitAnswer({
    required GameRoom room,
    required QuizQuestion question,
    required String selectedOptionOptionKey,
    required int responseMs,
  }) => Completer<Map<String, dynamic>>().future;
}

void main() {
  const nextKey = ValueKey('quiz-next-button');

  bool nextEnabled(WidgetTester tester) =>
      tester.widget<SahneButton>(find.byKey(nextKey)).onPressed != null;

  for (final hanging in [false, true]) {
    for (final experience in QuizExperience.values) {
      testWidgets(
        '2026-09-30 simülatör: ${hanging ? 'takılan' : 'çevrimdışı'} depo, '
        '${experience.name}: cevaptan sonra Sonraki 1 sn içinde etkin',
        (tester) async {
          SharedPreferences.setMockInitialValues({
            'zankurd.quiz_tutorial.seen': true,
            'zankurd.navTour.seen': true,
          });
          final repository = hanging
              ? _HangingRepository()
              : OfflineZanKurdRepository();
          await tester.pumpWidget(
            testShell(
              child: QuizScreen(
                repository: repository,
                room: repository.createRoom(),
                questions: const [_question],
                experience: experience,
                enableTimer: false,
                // Üretim değeri: test ortamı sıfıra indirirdi.
                suspenseHold: const Duration(milliseconds: 520),
              ),
            ),
          );
          await tester.pumpAndSettle();

          await tester.tap(find.text('ekmek'));
          await tester.pump();
          expect(
            nextEnabled(tester),
            isFalse,
            reason: 'gerilim tutuşu sırasında düğme kilitli olmalı',
          );

          // Tutuş (520) + yerel bekleme sınırı (300) = 820 ms < 1 sn.
          await tester.pump(const Duration(seconds: 1));
          expect(
            nextEnabled(tester),
            isTrue,
            reason: 'çevrimdışı turda Sonraki 1 sn içinde etkinleşmeli',
          );
          // Yerel değerlendirme sonucu geldi: yanlış cevap kaydedildi.
          await tester.pumpAndSettle(const Duration(seconds: 2));
        },
      );
    }
  }
}
