import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/providers/sound_provider.dart';
import 'package:zankurd_mobile/src/screens/quiz_screen.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';

void main() {
  testWidgets('öğrenme quizinde rekabet baskısı elemanları görünmez', (
    tester,
  ) async {
    final repository = MockZanKurdRepository();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => LanguageProvider()),
          ChangeNotifierProvider(create: (_) => SoundProvider()),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: QuizScreen(
            repository: repository,
            room: repository.createRoom(),
            questions: repository.questions.take(3).toList(),
            experience: QuizExperience.learning,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Puan'), findsNothing);
    expect(find.text('50/50'), findsNothing);
    expect(find.byIcon(Icons.volume_up_rounded), findsNothing);
  });
}
