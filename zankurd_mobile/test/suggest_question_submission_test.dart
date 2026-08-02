import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/screens/suggest_question_screen.dart';

import 'support/widget_test_helpers.dart';

class _SuggestionRepository extends MockZanKurdRepository {
  _SuggestionRepository(this.result);

  final bool result;

  @override
  Future<bool> submitSuggestedQuestion({
    required String category,
    required String prompt,
    required String optionA,
    required String optionB,
    required String optionC,
    required String optionD,
    required String correctOption,
    String? explanation,
    int difficulty = 3,
  }) async => result;
}

Future<void> _completeSuggestionForm(WidgetTester tester) async {
  await tester.tap(find.byType(DropdownButtonFormField<String>));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Dil').last);

  final fields = find.byType(TextFormField);
  await tester.enterText(fields.at(0), 'Pirtûk çi ye?');
  await tester.enterText(fields.at(1), 'Kitap');
  await tester.enterText(fields.at(2), 'Masa');
  await tester.enterText(fields.at(3), 'Av');
  await tester.enterText(fields.at(4), 'Mal');
}

void main() {
  Future<void> pumpScreen(WidgetTester tester, bool result) async {
    await tester.binding.setSurfaceSize(const Size(600, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      testShell(
        child: SuggestQuestionScreen(
          repository: _SuggestionRepository(result),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _completeSuggestionForm(tester);
  }

  testWidgets('false dönen soru önerisi hata gösterir ve formu korur', (
    tester,
  ) async {
    await pumpScreen(tester, false);

    await tester.ensureVisible(find.text('Soruyu Gönder'));
    await tester.tap(find.text('Soruyu Gönder'));
    await tester.pumpAndSettle();

    expect(find.text('Bir hata oluştu. Lütfen tekrar dene.'), findsOneWidget);
    expect(find.byType(Form), findsOneWidget);
    expect(find.text('Önerin için teşekkürler!'), findsNothing);
    expect(find.text('Pirtûk çi ye?'), findsOneWidget);
  });

  testWidgets('true dönen soru önerisi başarı görünümünü açar', (tester) async {
    await pumpScreen(tester, true);

    await tester.ensureVisible(find.text('Soruyu Gönder'));
    await tester.tap(find.text('Soruyu Gönder'));
    await tester.pumpAndSettle();

    expect(find.text('Önerin için teşekkürler!'), findsOneWidget);
    expect(find.byType(Form), findsNothing);
  });
}
