import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/answer_record.dart';
import 'package:zankurd_mobile/src/screens/quiz_result_screen.dart';
import 'package:zankurd_mobile/src/screens/review_screen.dart';

import 'support/widget_test_helpers.dart';

/// Tur özeti, sorunun **yazılmış** açıklamasını göstermeli.
///
/// 2026-07-27 Kurmancî taraması: özet ekranı doğrudan kural motoruna
/// gidiyordu (`resolveRawExplanation`) ve sorunun elle yazılmış Kurmancî
/// açıklamasını hiç görmüyordu. Motor eşleşme bulamayınca ham Türkçe metni
/// `Şirove: <cümle>` diye sarıyor; sarmak çevirmek değildir. Sonuç:
/// bankada yazılı Kurmancî açıklama varken bile Kurmancî oyuncuya Türkçe
/// cümle gösteriliyordu.
///
/// Sebep iki ayrı yoldu — soru ekranı `getLocalizedExplanation` kullanıyor,
/// özet ekranı kullanmıyordu. `AnswerRecord` zaten yazılmış açıklamaları
/// taşımıyordu; artık taşıyor.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  const record = AnswerRecord(
    id: 'rev-1',
    category: 'Ziman',
    prompt: 'Peyva «av» bi Tirkî çi tê gotin?',
    answers: ['su', 'ekmek'],
    correctAnswer: 'su',
    selectedAnswer: 'ekmek',
    explanation: '«av» Türkçede «su» demektir.',
    explanationKu: '«av» bi Tirkî dibe «su».',
    explanationTr: '«av» Türkçede «su» demektir.',
  );

  testWidgets('Kurmancî arayüzde yazılmış Kurmancî açıklama gösterilir', (
    tester,
  ) async {
    await tester.pumpWidget(
      testShell(
        child: ReviewScreen(
          room: MockZanKurdRepository().createRoom(),
          records: const [record],
        ),
        languageProvider: kurmanciLang(),
      ),
    );
    await tester.pump();

    expect(find.text('«av» bi Tirkî dibe «su».'), findsOneWidget);
    // Kural motorunun sarmalayıcısı hiç görünmemeli.
    expect(find.textContaining('Şirove:'), findsNothing);
  });

  testWidgets('Türkçe arayüzde yazılmış Türkçe açıklama gösterilir', (
    tester,
  ) async {
    // Karşı taraf: yalnız Kurmancî'yi düzeltmek Türkçe tarafı bozabilirdi.
    await tester.pumpWidget(
      testShell(
        child: ReviewScreen(
          room: MockZanKurdRepository().createRoom(),
          records: const [record],
        ),
      ),
    );
    await tester.pump();

    expect(find.text('«av» Türkçede «su» demektir.'), findsOneWidget);
  });

  testWidgets('tur sonu kartı da yazılmış Kurmancî açıklamayı gösterir', (
    tester,
  ) async {
    // Aynı kusur iki ekranda birden vardı ve asıl önemli olan burasıdır:
    // tur boyunca hiçbir açıklama gösterilmez, hepsi sonuç ekranında
    // toplanır. Yalnız özet ekranını düzeltmek, açıklamaların gerçekte
    // okunduğu yeri kusurlu bırakırdı.
    final repository = MockZanKurdRepository();
    await tester.pumpWidget(
      testShell(
        child: QuizResultScreen(
          repository: repository,
          room: repository.createRoom(),
          score: 100,
          correctCount: 0,
          wrongCount: 1,
          totalQuestions: 1,
          bestStreak: 0,
          coinsAwarded: 0,
          answerRecords: const [record],
        ),
        languageProvider: kurmanciLang(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('result-all-explanations')),
      300,
    );
    await tester.pumpAndSettle();

    expect(find.text('«av» bi Tirkî dibe «su».'), findsOneWidget);
    expect(find.textContaining('Şirove:'), findsNothing);
  });
}
