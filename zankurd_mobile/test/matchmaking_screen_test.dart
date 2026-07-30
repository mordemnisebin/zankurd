import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/data/xp_store.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/models/player.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/models/room.dart';
import 'package:zankurd_mobile/src/providers/sound_provider.dart';
import 'package:zankurd_mobile/src/screens/matchmaking_screen.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';

/// Eşleştirme iptalinin gerçekten çağrıldığını izleyen sahte depo.
class _TrackingRepository extends MockZanKurdRepository {
  int cancelCalls = 0;

  @override
  Future<void> cancelMatchmaking() async {
    cancelCalls += 1;
  }
}

enum _RoomQuestionResult { empty, failure }

class _HiddenAnswerMatchRepository extends MockZanKurdRepository {
  _HiddenAnswerMatchRepository(this.result);

  final _RoomQuestionResult result;
  int loadLevelCalls = 0;

  @override
  bool get usesServerHiddenAnswers => true;

  @override
  Future<Map<String, dynamic>> joinMatchmaking(String categoryName) async {
    return const {
      'status': 'matched',
      'room_id': '00000000-0000-0000-0000-000000000001',
      'opponent_name': 'Rojda',
    };
  }

  @override
  Future<List<QuizQuestion>> loadRoomQuestions(GameRoom room) async {
    if (result == _RoomQuestionResult.failure) {
      throw StateError('room questions unavailable');
    }
    return const [];
  }

  @override
  Future<List<QuizQuestion>> loadLevelQuestions({
    required String category,
    required int difficultyMin,
    required int difficultyMax,
    String? subCategory,
    int limit = 10,
  }) async {
    loadLevelCalls += 1;
    return super.loadLevelQuestions(
      category: category,
      difficultyMin: difficultyMin,
      difficultyMax: difficultyMax,
      subCategory: subCategory,
      limit: limit,
    );
  }
}

Widget _shell(Widget child) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<LanguageProvider>(
        create: (_) => LanguageProvider()..setLang('tr'),
      ),
      ChangeNotifierProvider<SoundProvider>(create: (_) => SoundProvider()),
    ],
    child: MaterialApp(theme: AppTheme.dark(), home: child),
  );
}

Future<void> _startImmediateMatch(
  WidgetTester tester,
  _HiddenAnswerMatchRepository repository,
) async {
  tester.view.physicalSize = const Size(480, 1600);
  tester.view.devicePixelRatio = 1.0;

  await tester.pumpWidget(
    _shell(MatchmakingScreen(repository: repository)),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Rastgele eşleşme'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 1501));
  await tester.pump();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    XPStore.resetInstance();
  });

  test('kanonik rakip adı varsa oda listesinden aynı oyuncu seçilir', () {
    const players = [
      Player(id: 'host', name: 'Ben', score: 0, state: 'Hazır'),
      Player(id: 'wrong', name: 'Dilan', score: 0, state: 'Hazır'),
      Player(id: 'matched', name: 'Hogir', score: 0, state: 'Hazır'),
    ];

    expect(
      selectOpponentPlayer(
        players,
        currentName: 'Ben',
        preferredName: 'Hogir',
      )?.id,
      'matched',
    );
  });

  testWidgets('seçim menüsü 1vs1 girişini ve rastgele eşleşmeyi gösterir', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(480, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _shell(MatchmakingScreen(repository: MockZanKurdRepository())),
    );
    await tester.pumpAndSettle();

    expect(find.text('1vs1 Düello'), findsOneWidget);
    expect(find.text('Rastgele eşleşme'), findsOneWidget);
    final duelCard = tester.widget<Container>(
      find.byKey(const ValueKey('matchmaking-duel-card')),
    );
    final decoration = duelCard.decoration! as BoxDecoration;
    expect(decoration.border, isNotNull);
    expect(decoration.gradient, isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ekrandan çıkınca eşleştirme kuyruğu iptal edilir', (
    tester,
  ) async {
    final repository = _TrackingRepository();
    await tester.pumpWidget(_shell(MatchmakingScreen(repository: repository)));
    await tester.pumpAndSettle();

    // Ekranı kaldır: dispose, kuyruğu sunucuda da temizlemeli ki oyuncu
    // hayalet kayıt olarak eşleşme kuyruğunda kalmasın.
    await tester.pumpWidget(_shell(const SizedBox()));
    await tester.pumpAndSettle();

    expect(repository.cancelCalls, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('gizli cevaplı gerçek eşleşmede boş oda soruları yerele düşmez', (
    tester,
  ) async {
    final repository = _HiddenAnswerMatchRepository(
      _RoomQuestionResult.empty,
    );
    addTearDown(tester.view.reset);

    await _startImmediateMatch(tester, repository);

    expect(repository.loadLevelCalls, 0);
    expect(find.text('Oyun başlatılamadı. Tekrar dene.'), findsOneWidget);
  });

  testWidgets('oda sorusu hatası eşleşti görünümünü kapatıp iptali açar', (
    tester,
  ) async {
    final repository = _HiddenAnswerMatchRepository(
      _RoomQuestionResult.failure,
    );
    addTearDown(tester.view.reset);

    await _startImmediateMatch(tester, repository);

    expect(find.text('Başlamak üzere...'), findsNothing);
    expect(find.text('İptal Et'), findsOneWidget);
    expect(find.text('Oyun başlatılamadı. Tekrar dene.'), findsOneWidget);
  });
}
