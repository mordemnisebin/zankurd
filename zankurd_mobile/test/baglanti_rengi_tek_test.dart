// 7. tasarım kurulu (2026-10-20): metin bağlantısı rengi ekrana göre
// değişiyordu — profilde turuncu, sonuçta yeşil ("… yanlışlarını gözden
// geçir"), odada lacivert-gri ("Arkadaşlarını davet et").
//
// ## Niçin sessiz kalırdı
//
// Her ekran kendi belirtecini seçiyordu (`learnTx`, `tx2`, `actTx`); hiçbiri
// derleme ya da analiz hatası değil, hepsi "geçerli renk". Hiçbir test iki
// ekranın aynı eylem türünü aynı renkle çizdiğini karşılaştırmıyordu. Bu
// bekçi tek belirteci (`linkTx`) sabitler ve sonuç kartı bağlantısının ona
// bağlı olduğunu doğrular; yeşil yalnız doğruya kalır.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/models/answer_record.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';
import 'package:zankurd_mobile/src/theme/sahne.dart';
import 'package:zankurd_mobile/src/widgets/learning_outcome_card.dart';

Widget _wrap(Widget child, {required bool dark}) =>
    ChangeNotifierProvider<LanguageProvider>(
      create: (_) => LanguageProvider()..setLang('tr'),
      child: MaterialApp(
        theme: dark ? AppTheme.dark() : AppTheme.light(),
        home: Scaffold(body: child),
      ),
    );

void main() {
  for (final dark in [false, true]) {
    testWidgets('sonuç kartı bağlantısı linkTx rengindedir, yeşil değil '
        '(${dark ? 'koyu' : 'açık'})', (tester) async {
      final outcome = LearningOutcome.fromRecords(const [
        AnswerRecord(
          id: '1',
          category: 'Tarih',
          prompt: 'Pirs',
          answers: ['A', 'B'],
          correctAnswer: 'A',
          selectedAnswer: 'B',
          explanation: 'x',
        ),
      ]);
      await tester.pumpWidget(
        _wrap(
          LearningOutcomeCard(
            outcome: outcome,
            onReview: () {},
            showCounts: false,
          ),
          dark: dark,
        ),
      );
      final t = SahneTokens.of(tester.element(find.byType(Scaffold)));
      final link = tester.widget<Text>(
        find.textContaining('yanlışlarını gözden geçir'),
      );
      expect(link.style?.color, t.linkTx);
      expect(t.linkTx, isNot(t.okTx));
      expect(t.linkTx, isNot(t.learnTx));
      expect(t.linkTx, t.actTx);
    });
  }
}
