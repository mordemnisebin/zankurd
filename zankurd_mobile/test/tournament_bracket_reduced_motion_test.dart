import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/models/tournament.dart';
import 'package:zankurd_mobile/src/providers/reduced_motion_provider.dart';
import 'package:zankurd_mobile/src/widgets/tournament_bracket_widget.dart';

/// Maç kartı kenarlık/gölge geçişi 350 ms `AnimatedContainer` ile
/// oynatılıyordu ve "hareketi azalt" tercihini hiç okumuyordu.
///
/// Renk ve gölge süsüdür, skor taşımaz: tercih açıkken süre sıfır olmalı.
/// Aksi hâlde ayar, turnuva şemasındaki her kartta yok sayılmış olur —
/// çevrimdışı şerit ve birincil CTA aynı kapıdan geçiyor.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('hareketi azalt açıkken maç kartı animasyonsuz durur', (
    tester,
  ) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => ReducedMotionProvider(initialUserReduce: true),
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 600,
              child: TournamentBracketWidget(
                bracket: _oneMatch(),
                userId: 'user',
                ku: false,
              ),
            ),
          ),
        ),
      ),
    );

    final card = tester.widget<AnimatedContainer>(
      find.byType(AnimatedContainer),
    );
    expect(card.duration, Duration.zero);
  });

  testWidgets('tercih kapalıyken maç kartı 350 ms animasyonla değişir', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 600,
            child: TournamentBracketWidget(
              bracket: _oneMatch(),
              userId: 'user',
              ku: false,
            ),
          ),
        ),
      ),
    );

    final card = tester.widget<AnimatedContainer>(
      find.byType(AnimatedContainer),
    );
    expect(card.duration, const Duration(milliseconds: 350));
  });
}

TournamentBracket _oneMatch() {
  return TournamentBracket(
    tournamentId: 'daily',
    userId: 'user',
    rounds: const [
      TournamentRound(
        roundNumber: 1,
        status: 'active',
        matches: [
          TournamentMatch(
            id: 'r0m0',
            playerOneId: 'user',
            playerOneName: 'Rojhat',
            playerTwoId: 'rival',
            playerTwoName: 'Rakip',
            playerOneScore: 0,
            playerTwoScore: 0,
            status: 'active',
            winnerId: '',
          ),
        ],
      ),
    ],
    currentRound: 0,
    status: 'active',
    createdAt: DateTime.utc(2026, 9, 7),
  );
}
