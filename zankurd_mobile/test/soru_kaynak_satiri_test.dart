import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/question_metadata.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/screens/quiz_screen.dart';

import 'support/widget_test_helpers.dart';

/// Cevap sonrası "Kaynak: …" satırının bekçisi (2026-11-04).
///
/// ## Kusur
///
/// Soru künyesi (`sourceTitle` / `sourceReference`; sunucuda `source_title` /
/// `source_reference` / `source_url`) modelde ve 3000+ soruda vardı ama
/// oyuncuya HİÇ gösterilmiyordu: "bu doğru mu?" diyen oyuncunun doğrulayacağı
/// bir yer yoktu (rakip uygulamalar kaynak gösteriyor).
///
/// ## Niçin sessiz kalırdı
///
/// Künye alanları dolu ama okunmuyordu; hiçbir ekran, test ya da analiz bunu
/// "eksik" saymaz. Ters yönde de sessiz bozulur: paketli soruların
/// `sourceTitle`ı çoğunlukla iç iz sürme etiketidir ("ZanKurd başlangıç dersi:
/// …", `internal:` başvurular) ve sunucudaki `source_url` bazı satırlarda
/// bağlantı değil toplu-yükleme etiketidir ("curated_movement_wave_1");
/// süzgeçsiz gösterim oyuncuya anlamsız ya da tıklanınca ölü bağlantı
/// verirdi. Satır yerleşimi bozarsa da (kaydırma, taşma) hiçbir derleme hatası
/// yoktur.
///
/// ## Kural
///
/// * Gösterilecek künye [QuestionMetadata.displaySource]tan gelir; iç etiket
///   ve http(s) olmayan bağlantı elenir; boşsa satır HİÇ yer kaplamaz.
/// * Sunucu satırındaki üç sütun künyeye taşınır ([QuizQuestion.fromServerRow]).
/// * Satır açıklama SAYFASINDA ([QuestionSourceLine]) görünür; cevaptan sonra
///   beliren yanlış-cevap kartına KONMAZ: ekstra satır ortalanmış soru+şık
///   grubunu kaydırırdı (son_kurul_test B, ilk denemede kırıldı).
void main() {
  group('displaySource süzgeci', () {
    test('wikipedia bağlantılı paketli künye: sunucu adı + bağlantı', () {
      const m = QuestionMetadata(
        sourceTitle: 'en.wikipedia.org',
        sourceReference: 'https://en.wikipedia.org/wiki/Kurdistan',
      );
      final s = m.displaySource!;
      expect(s.label, 'en.wikipedia.org');
      expect(s.url, Uri.parse('https://en.wikipedia.org/wiki/Kurdistan'));
    });

    test('iç iz sürme etiketi gösterilmez; bağlantı yoksa satır yok', () {
      for (final title in [
        'ZanKurd başlangıç dersi: intro_1',
        'Source-first verified expansion 2026-08',
        'Kolay soru taslağı 2026-10-19',
        'Topluluk katkısı',
      ]) {
        final m = QuestionMetadata(
          sourceTitle: title,
          sourceReference: 'internal:expansion_2026_08/tec',
        );
        expect(m.displaySource, isNull, reason: title);
      }
    });

    test('iç etiketli başlık + http bağlantı: sunucu adı gösterilir', () {
      const m = QuestionMetadata(
        sourceTitle: 'ZanKurd dil bilgisi dersi: izafe_1',
        sourceReference: 'https://ku.wikipedia.org/wiki/Ziman',
      );
      expect(m.displaySource!.label, 'ku.wikipedia.org');
      expect(m.displaySource!.url, isNotNull);
    });

    test('kitap künyesi: başlık gösterilir, bağlantı olmaz', () {
      const m = QuestionMetadata(
        sourceTitle: 'Rêzimana kurdî — Bedirxan & Lescot',
        sourceReference: 'Celadet Alî Bedirxan & Roger Lescot, 1970',
      );
      final s = m.displaySource!;
      expect(s.label, contains('Bedirxan'));
      expect(s.url, isNull);
    });

    test('boş künye: null', () {
      expect(const QuestionMetadata().displaySource, isNull);
    });
  });

  group('sunucu satırı', () {
    Map<String, dynamic> row(Map<String, dynamic> extra) => {
      'id': 'q1',
      'prompt': 'p',
      'option_a': 'a',
      'option_b': 'b',
      'option_c': 'c',
      'option_d': 'd',
      ...extra,
    };

    test('source_* sütunları künyeye taşınır', () {
      final q = QuizQuestion.fromServerRow(
        row({
          'source_title': 'Wikipedia',
          'source_url': 'https://ku.wikipedia.org/wiki/Av',
        }),
      );
      expect(q.metadata!.displaySource!.label, 'Wikipedia');
      expect(q.metadata!.displaySource!.url!.host, 'ku.wikipedia.org');
    });

    test('toplu-yükleme etiketi olan source_url bağlantı sayılmaz', () {
      final q = QuizQuestion.fromServerRow(
        row({'source_url': 'curated_movement_wave_1'}),
      );
      expect(q.metadata?.displaySource, isNull);
    });

    test('sütun yoksa metadata null (eski RPC)', () {
      expect(QuizQuestion.fromServerRow(row({})).metadata, isNull);
    });
  });

  group('ekran', () {
    const kaynakli = QuizQuestion(
      id: 'kaynak-1',
      category: 'Ziman',
      prompt: 'Peyva «av» bi Tirkî çi tê gotin?',
      answers: ['su', 'ekmek', 'yol', 'dağ'],
      correctAnswer: 'su',
      explanation: '«av» Türkçede «su» demektir.',
      metadata: QuestionMetadata(
        sourceTitle: 'ku.wikipedia.org',
        sourceReference: 'https://ku.wikipedia.org/wiki/Av',
      ),
    );
    const sonraki = QuizQuestion(
      id: 'kaynak-2',
      category: 'Ziman',
      prompt: 'Peyva «nan» bi Tirkî çi tê gotin?',
      answers: ['ekmek', 'su', 'yol', 'dağ'],
      correctAnswer: 'ekmek',
      explanation: '«nan» Türkçede «ekmek» demektir.',
    );

    Future<void> pump(WidgetTester tester, QuizExperience experience) async {
      SharedPreferences.setMockInitialValues({
        'zankurd.quiz_tutorial.seen': true,
        'zankurd.navTour.seen': true,
      });
      tester.view.physicalSize = const Size(375, 667);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final repository = MockZanKurdRepository();
      await tester.pumpWidget(
        testShell(
          child: QuizScreen(
            repository: repository,
            room: repository.createRoom(),
            questions: const [kaynakli, sonraki],
            experience: experience,
            enableTimer: false,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    const satir = ValueKey('quiz-question-source');

    testWidgets('açıklama sayfası kaynağı gösterir; cevaptan önce yok', (
      tester,
    ) async {
      await pump(tester, QuizExperience.learning);
      expect(find.byKey(satir), findsNothing);
      await tester.tap(find.text('su'));
      await tester.pumpAndSettle(const Duration(seconds: 2));
      // Kapı düğmesi ve sayfa dışında satır yok (yer kaplamaz).
      expect(find.byKey(satir), findsNothing);
      await tester.tap(find.byKey(const ValueKey('quiz-view-explanation')));
      await tester.pumpAndSettle();
      expect(find.byKey(satir), findsOneWidget);
      expect(find.text('Kaynak: ku.wikipedia.org'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'yanlış-cevap kartı kaynak satırı taşımaz (cevaptan sonra kayma yok)',
      (tester) async {
        await pump(tester, QuizExperience.competition);
        await tester.tap(find.text('ekmek'));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('quiz-wrong-answer-insight')),
          findsOneWidget,
        );
        expect(find.byKey(satir), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
