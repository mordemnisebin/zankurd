/// Turnuva maçı sonuç ekranı bekçisi.
///
/// ## Kusur
///
/// Gerçek turnuvada maç bitince sıradan tek kişilik oyunun sonuç ekranı
/// çıkıyordu: uydurma bot rakiplerle kıyas ("Hêlîn önde bitirdi; sen 2.
/// sıradasın"), "Tekrar oyna" düğmesi ve bu düğmeyle ana sayfaya atılma.
/// Oyuncu maçının ne olduğunu görmek için turnuvayı yeniden açmak zorunda
/// kalıyordu (4 simülatörlü tur, 2026-10-27).
///
/// ## Niçin sessiz kalırdı
///
/// Turnuva ekranı maçı `botRace: true` ile açıyordu; bot yarışı tek kişilik
/// akışın parçası olduğu için sonuç ekranı onu "rakipler" diye gösterdi ve
/// hiçbir test turnuvadan açılan sonucun düğmesine bakmadı.
///
/// ## Kural
///
/// Turnuva maçının sonucunda ana eylem "Turnuvaya dön"dür ve çağıran ekrana
/// (şemaya) döner; bot kıyası yalnız antrenman kupasında vardır.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/screens/quiz_result_screen.dart';

import 'support/widget_test_helpers.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({'zankurd.onboarding.seen': true});
  });

  testWidgets('turnuva maçı sonucu "Turnuvaya dön" ile şemaya döner', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = MockZanKurdRepository();

    await tester.pumpWidget(
      testShell(
        child: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => QuizResultScreen(
                      repository: repository,
                      room: repository.createRoom(),
                      score: 383,
                      correctCount: 2,
                      wrongCount: 2,
                      totalQuestions: 4,
                      bestStreak: 1,
                      coinsAwarded: 0,
                      answerRecords: const [],
                      tournamentMatch: true,
                    ),
                  ),
                ),
                child: const Text('Şema'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Şema'));
    await tester.pumpAndSettle();

    expect(find.text('Tekrar oyna'), findsNothing);
    expect(find.text('Rakiplerle karşılaştır'), findsNothing);
    final back = find.text('Turnuvaya dön');
    expect(back, findsOneWidget);

    await tester.tap(back);
    await tester.pumpAndSettle();
    expect(find.byType(QuizResultScreen), findsNothing);
    expect(find.text('Şema'), findsOneWidget, reason: 'çağıran ekrana döner');
  });
}
