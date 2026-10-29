import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/async_duel.dart';
import 'package:zankurd_mobile/src/screens/async_duel/async_duel_inbox.dart';

import 'support/widget_test_helpers.dart';

/// "Sıra sende" bölümü ikiden fazla bekleyen düelloyu gizlemez.
///
/// ## Kusur (Codex denetimi 2026-10-29, ürün #9)
///
/// Üst bölüm yalnız `maxRows` (2) satır çiziyordu; alttaki "Düellolarım"
/// kutusu ise dikkat isteyenleri zaten dışlıyordu. Üçüncü bekleyen
/// arkadaş hiçbir yerde görünmüyordu.
///
/// ## Niçin sessiz kalırdı
///
/// Testler en çok bir-iki bekleyen düelloyla kuruluyordu; üçüncüsü hiç
/// sahnelenmiyordu.
///
/// ## Kural
///
/// Bekleyen sayısı `maxRows`ı aşarsa "Tümü (N)" bağlantısı çizilir.
class _ManyWaitingRepository extends MockZanKurdRepository {
  _ManyWaitingRepository(this.count);

  final int count;

  @override
  Future<List<AsyncDuelSummary>> loadMyAsyncDuels() async => [
    for (var i = 0; i < count; i++)
      AsyncDuelSummary(
        duelId: 'd$i',
        status: AsyncDuelStatus.open,
        role: AsyncDuelRole.opponent,
        opponentName: 'Rojda $i',
        createdAt: DateTime.utc(2026, 10, 24).add(Duration(minutes: i)),
        seen: true,
        incomingChallenge: true,
        challengeCode: 'KOD$i',
        expiresAt: DateTime.now().toUtc().add(const Duration(hours: 20)),
      ),
  ];
}

Future<void> _pump(WidgetTester tester, int count) async {
  await tester.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    testShell(
      child: Scaffold(
        body: SingleChildScrollView(
          child: AsyncDuelTurnSection(
            repository: _ManyWaitingRepository(count),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('üç bekleyen düelloda "Tümü (3)" bağlantısı görünür', (
    tester,
  ) async {
    await _pump(tester, 3);
    expect(
      find.byKey(const ValueKey('async-duel-turn-see-all')),
      findsOneWidget,
    );
    expect(find.textContaining('(3)'), findsOneWidget);
  });

  testWidgets('iki bekleyen düelloda bağlantı çizilmez', (tester) async {
    await _pump(tester, 2);
    expect(find.byKey(const ValueKey('async-duel-turn-see-all')), findsNothing);
  });
}
