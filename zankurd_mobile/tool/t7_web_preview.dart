// T7 görsel bekçisi: yalnız bellek içi veri, ağ/oturum kurulumu yok.
// flutter run -d web-server --target tool/t7_web_preview.dart --web-port 8177
// ?screen=duel|rewards|auth&lang=tr|ku&scale=1.3
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/main.dart' show ZanKurdApp;
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/models/player.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/models/room.dart';
import 'package:zankurd_mobile/src/providers/theme_provider.dart';
import 'package:zankurd_mobile/src/screens/quiz_screen.dart';
import 'package:zankurd_mobile/src/widgets/auth_social_buttons.dart';
import 'package:zankurd_mobile/src/widgets/sahne/sahne.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Test girişi; tarayıcının gerçek tercihlerini yazmaz.
  // ignore: invalid_use_of_visible_for_testing_member
  SharedPreferences.setMockInitialValues({
    'zankurd.quiz_tutorial.seen': true,
    'zankurd.navTour.seen': true,
  });
  final query = Uri.base.queryParameters;
  final repo = MockZanKurdRepository();
  final child = switch (query['screen']) {
    'auth' => Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: AuthSocialButtons(
            linking: true,
            showApple: true,
            onApple: () {},
            onGoogle: () {},
          ),
        ),
      ),
    ),
    'rewards' => const Scaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: SahneResultRewards(
            coins: 1202,
            xp: 1202,
            progress: SahneResultLevelProgress(
              levelLabel: '12',
              xpInLevel: 1436,
              xpNeeded: 2500,
              progress: 1436 / 2500,
            ),
          ),
        ),
      ),
    ),
    _ => QuizScreen(
      repository: repo,
      enableTimer: false,
      is1v1: true,
      room: const GameRoom(
        id: 't7',
        name: 'T7',
        code: 'T7',
        category: 'Ziman',
        status: RoomStatus.active,
        questionCount: 1,
        players: [
          Player(id: 'user', name: 'Ali', score: 99999, streak: 5, state: ''),
          Player(id: 'other', name: 'Bero', score: 12345, streak: 5, state: ''),
        ],
      ),
      questions: const [
        QuizQuestion(
          id: 't7',
          category: 'Ziman',
          prompt: 'Yek + yek?',
          promptTr: 'Bir + bir?',
          answers: ['2', '3', '4', '5'],
          correctAnswer: '2',
          explanation: '',
        ),
      ],
    ),
  };
  runApp(
    ZanKurdApp(
      repository: repo,
      languageProvider: LanguageProvider(initialLang: query['lang'] ?? 'tr'),
      themeProvider: ThemeProvider(initialMode: ThemeMode.dark),
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(
              double.tryParse(query['scale'] ?? '') ?? 1,
            ),
          ),
          child: child,
        ),
      ),
    ),
  );
}
