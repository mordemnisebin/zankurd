import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/l10n/strings.dart';
import 'package:zankurd_mobile/src/models/contest.dart';
import 'package:zankurd_mobile/src/screens/contest_screen.dart';
import 'package:zankurd_mobile/src/screens/quiz_screen.dart';

import 'support/widget_test_helpers.dart';

class _TrackingContestRepository extends MockZanKurdRepository {
  int leaderboardCalls = 0;

  @override
  Future<List<ContestLeaderboardRow>> getContestLeaderboard({
    required String contestId,
    int limit = 10,
  }) async {
    leaderboardCalls++;
    return super.getContestLeaderboard(contestId: contestId, limit: limit);
  }
}

void main() {
  test('günlük etkinlik iki dilde 10 soruluk ilerleme olarak tanımlanır', () {
    expect(Tr.of(K.dailyContest, AppLanguage.tr), 'Günün Etkinliği');
    expect(Tr.of(K.dailyContest, AppLanguage.ku), 'Çalakiya Rojê');

    final trCopy = [
      Tr.of(K.dailyEventSub, AppLanguage.tr),
      Tr.of(K.contestNoneToday, AppLanguage.tr),
      Tr.of(K.howToPlayBody, AppLanguage.tr),
      Tr.of(K.onbDuelBullet, AppLanguage.tr),
    ].join(' ');
    final kuCopy = [
      Tr.of(K.dailyEventSub, AppLanguage.ku),
      Tr.of(K.contestNoneToday, AppLanguage.ku),
      Tr.of(K.howToPlayBody, AppLanguage.ku),
      Tr.of(K.onbDuelBullet, AppLanguage.ku),
    ].join(' ');

    expect(trCopy, contains('10'));
    expect(trCopy, contains('Günün Etkinliği'));
    expect(trCopy.toLowerCase(), isNot(contains('ödül')));
    expect(trCopy.toLowerCase(), isNot(contains('sıralama')));
    expect(kuCopy, contains('10'));
    expect(kuCopy, contains('Çalakiya Rojê'));
    expect(kuCopy.toLowerCase(), isNot(contains('xelat')));
    expect(kuCopy.toLowerCase(), isNot(contains('pêşderçûn')));
  });

  testWidgets(
    'günlük etkinlik yalnız ilerleme sunar ve doğrulanamayan contest akışını açmaz',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      freshMockRepository();
      final repository = _TrackingContestRepository();

      await tester.pumpWidget(
        testShell(child: ContestScreen(repository: repository)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Günün Etkinliği'), findsWidgets);
      expect(find.text('Günün Yarışması'), findsNothing);
      expect(find.textContaining('Ödül:'), findsNothing);
      expect(find.text('Katıl ve sıralamada yerini al.'), findsNothing);
      expect(find.text('Sıralama'), findsNothing);
      expect(find.text('Dil'), findsNothing);
      expect(find.text('Dil Uzmanı'), findsNothing);
      expect(find.text('Dilin ustası ol!'), findsNothing);
      expect(find.text('Günün 10 Sorusu'), findsOneWidget);
      expect(
        find.text('Farklı konulardan karışık soruları cevapla.'),
        findsOneWidget,
      );
      expect(find.text('1-3'), findsNothing);
      expect(find.text('10 soru'), findsOneWidget);
      expect(repository.leaderboardCalls, 0);

      await tester.ensureVisible(find.text('Etkinliğe başla'));
      await tester.tap(find.text('Etkinliğe başla'));
      await tester.pumpAndSettle();

      final quiz = tester.widget<QuizScreen>(find.byType(QuizScreen));
      expect(quiz.dailyQuiz, isTrue);
      expect(quiz.contestId, isNull);
      expect(quiz.room.category, 'Tevlihev');
      expect(quiz.room.name, 'Günün Etkinliği');
    },
  );
}
