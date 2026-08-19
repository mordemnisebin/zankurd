import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/data/placement_store.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/screens/level_placement_screen.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';

/// Seviye belirleme sınavı, banka Kurmancî sabittir (bkz. `QuizQuestion`
/// doc'u); quiz_screen.dart soruları `.localized(isKu: ...)` ile hedef
/// dile yansıtıp gösteriyordu, bu ekran ise doğrudan ham `prompt`/`answers`
/// alanlarını basıyordu. Türkçe seçili kullanıcı, Türkçe karşılığı olan
/// bir soruda bile Kurmancî metin görüyordu (2026-08-14 denetimi).
class _TranslatedQuestionRepository extends MockZanKurdRepository {
  @override
  List<QuizQuestion> get playableQuestions => const [
    QuizQuestion(
      id: 'q1',
      category: 'Ziman',
      prompt: 'Kîjan peyv rast e?',
      answers: ['Rast', 'Şaş', 'Ne diyar', 'Her du jî'],
      correctAnswer: 'Rast',
      explanation: '',
      promptTr: 'Hangi kelime doğru?',
      answersTr: ['Doğru', 'Yanlış', 'Belirsiz', 'İkisi de'],
      correctAnswerTr: 'Doğru',
      difficulty: 2,
    ),
  ];
}

Widget _wrap(Widget child) => ChangeNotifierProvider<LanguageProvider>(
  create: (_) => LanguageProvider()..setLang('tr'),
  child: MaterialApp(theme: AppTheme.light(), home: child),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PlacementStore.resetInstance();
  });

  testWidgets('Türkçe modda çevirisi olan soru Türkçe metinle gösterilir', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        LevelPlacementScreen(
          repository: _TranslatedQuestionRepository(),
          questionCount: 1,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Hangi kelime doğru?'), findsOneWidget);
    expect(find.text('Doğru'), findsOneWidget);
    expect(find.text('Kîjan peyv rast e?'), findsNothing);
    expect(find.text('Rast'), findsNothing);
  });
}
