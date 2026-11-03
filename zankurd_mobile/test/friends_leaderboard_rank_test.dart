import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/models/friend.dart';
import 'package:zankurd_mobile/src/models/leaderboard_period.dart';
import 'package:zankurd_mobile/src/screens/leaderboard_screen.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';

/// Arkadaş sıralamasında soldaki sayı SIRAdır, seviye değil.
///
/// 2026-11-03 simülatör turu: satırın solundaki kare `friend.level`
/// yazıyordu; 187 puanlı satırda "3", 177 puanlıda "2", dördüncüde "4"
/// görünüyordu. Oyuncu bunu sıra okudu ve sıra ile satır sırası
/// çelişti. Sessizdi: veri doğruydu (sunucu puana göre sıralıyor), yalnız
/// yanlış alan sıra konumunda çiziliyordu. Bekçi, kaynak sırası karışık
/// gelse de satırların puana göre dizildiğini, karedeki sayının konum
/// olduğunu ve kendi satırının "Sen" rozetini taşıdığını ölçer.
class _Repo extends MockZanKurdRepository {
  _Repo(this.friends);
  final List<Friend> friends;

  @override
  Future<List<Friend>> loadFriendsLeaderboard({
    LeaderboardPeriod period = LeaderboardPeriod.weekly,
  }) async => friends;
}

Friend _f(String id, String name, int score, int level) => Friend(
  id: id,
  userId: 'user',
  friendId: id,
  friendName: name,
  createdAt: DateTime(2026, 7, 1),
  totalScore: score,
  level: level,
);

void main() {
  testWidgets('sıra numarası satır konumudur; puana göre dizilir', (
    tester,
  ) async {
    final repo = _Repo([
      _f('a', 'Aso', 177, 2),
      _f('user', 'Ben', 187, 3),
      _f('c', 'Cano', 177, 9),
      _f('d', 'Dara', 10, 4),
    ]);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<LanguageProvider>(
            create: (_) => LanguageProvider(initialLang: 'tr'),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(body: LeaderboardScreen(repository: repo)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Arkadaş'));
    await tester.pumpAndSettle();

    final order = ['user', 'a', 'c', 'd'];
    double? lastTop;
    for (final (i, id) in order.indexed) {
      final row = find.byKey(ValueKey('friend-rank-row-$id'));
      expect(row, findsOneWidget);
      final top = tester.getTopLeft(row).dy;
      if (lastTop != null) expect(top, greaterThan(lastTop));
      lastTop = top;
      final number = tester.widget<Text>(
        find.byKey(ValueKey('friend-rank-number-$id')),
      );
      expect(number.data, '${i + 1}', reason: '$id satırının sırası');
    }
    expect(
      find.byKey(const ValueKey('friend-self-badge-user')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('friend-self-badge-a')), findsNothing);
  });
}
