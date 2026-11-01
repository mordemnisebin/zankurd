// G17–G19 çevrimdışı görsel bekçisi; Firebase/Supabase başlatmaz.
// flutter run -d web-server -t tool/g17_g19_web_preview.dart --web-port 8189
// ?screen=score|learning|flashcard&scale=2&lang=tr|ku&dark=true
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/main.dart' show ZanKurdApp;
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/player.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/models/room.dart';
import 'package:zankurd_mobile/src/providers/theme_provider.dart';
import 'package:zankurd_mobile/src/screens/learning_screen.dart';
import 'package:zankurd_mobile/src/screens/quiz_screen.dart';

import '../test/support/t8_visual_fixtures.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // ignore: invalid_use_of_visible_for_testing_member
  SharedPreferences.setMockInitialValues({
    'zankurd.quiz_tutorial.seen': true,
    'zankurd.navTour.seen': true,
  });
  final query = Uri.base.queryParameters;
  final repo = MockZanKurdRepository();
  final lessons = await repo.loadLessonsByCategory('everyday');
  final Widget screen = switch (query['screen']) {
    'learning' => LearningScreen(repository: repo),
    'flashcard' => LessonDetailScreen(
      lesson: lessons.first,
      repository: repo,
      initialFlashcardMode: true,
    ),
    _ => QuizScreen(
      repository: repo,
      enableTimer: false,
      room: const GameRoom(
        id: 'g19',
        name: 'Oda',
        code: 'G19',
        category: 'Ziman',
        status: RoomStatus.active,
        questionCount: 1,
        maxPlayers: 4,
        isCustom: true,
        hostId: 'h',
        players: [
          Player(
            id: 'user',
            name: 'Tolhildan Mawal',
            score: 12345,
            state: 'Hazır',
          ),
          Player(name: 'Rakip Oyuncu', score: 99999, state: 'Hazır'),
          Player(name: 'Üçüncü', score: 8765, state: 'Hazır'),
          Player(name: 'Dördüncü', score: 54321, state: 'Hazır'),
        ],
      ),
      questions: const [
        QuizQuestion(
          id: 'g19-question',
          category: 'Ziman',
          prompt: 'Silav',
          promptTr: 'Merhaba',
          answers: ['A', 'B', 'C', 'D'],
          correctAnswer: 'A',
          explanation: '',
        ),
      ],
    ),
  };
  runApp(
    ZanKurdApp(
      repository: repo,
      authProvider: T8VisualAuthProvider(),
      languageProvider: LanguageProvider(initialLang: query['lang'] ?? 'tr'),
      themeProvider: ThemeProvider(
        initialMode: query['dark'] == 'true' ? ThemeMode.dark : ThemeMode.light,
      ),
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(
              double.tryParse(query['scale'] ?? '') ?? 1,
            ),
          ),
          child: screen,
        ),
      ),
    ),
  );
}
