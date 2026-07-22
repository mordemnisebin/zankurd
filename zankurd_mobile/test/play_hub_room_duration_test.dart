import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/room.dart';
import 'package:zankurd_mobile/src/screens/play_hub_screen.dart';

import 'support/widget_test_helpers.dart';

/// 2026-07-21 denetiminde bulundu: oda kurucusunun soru başına süre
/// belirleme tercihi diye bir UI hiç yoktu — repository/DB katmanı
/// `secondsPerQuestion` alanını destekliyordu ama hiçbir ekran bunu
/// kullanıcıya sormuyordu, her zaman varsayılan (30sn) kullanılıyordu.
class _CapturingRepository extends MockZanKurdRepository {
  int? capturedSeconds;

  @override
  Future<GameRoom> createOnlineRoom({
    String category = 'Ziman',
    int secondsPerQuestion = GameRoom.defaultSecondsPerQuestion,
  }) async {
    capturedSeconds = secondsPerQuestion;
    return super.createOnlineRoom(
      category: category,
      secondsPerQuestion: secondsPerQuestion,
    );
  }
}

void main() {
  testWidgets(
    'oda kurucusu soru başına süreyi seçebilir ve seçim odaya uygulanır',
    (tester) async {
      final repository = _CapturingRepository();
      await tester.pumpWidget(
        testShell(child: PlayHubScreen(repository: repository)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Oda Kur'));
      await tester.pumpAndSettle();

      // Varsayılan seçim 30 sn olmalı; 45 sn'yi seçip onaylayalım.
      expect(find.text('30 sn'), findsOneWidget);
      await tester.tap(find.text('45 sn'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Odayı Aç'));
      await tester.pumpAndSettle();

      expect(repository.capturedSeconds, 45);
    },
  );

  /// 2026-07-22 canlı denetimi: sayfa 15 sn seçeneği de sunuyordu, ama bu
  /// değer GameRoom.allowedSecondsPerQuestion içinde yok. UI kendi listesini
  /// tutmasın; tek kaynak model olsun.
  testWidgets('süre seçenekleri modelin izinli kümesiyle birebir aynı', (
    tester,
  ) async {
    await tester.pumpWidget(
      testShell(child: PlayHubScreen(repository: MockZanKurdRepository())),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Oda Kur'));
    await tester.pumpAndSettle();

    for (final seconds in GameRoom.allowedSecondsPerQuestion) {
      expect(
        find.text('$seconds sn'),
        findsOneWidget,
        reason: '$seconds sn seçeneği eksik',
      );
    }
    expect(find.text('15 sn'), findsNothing);
  });
}
