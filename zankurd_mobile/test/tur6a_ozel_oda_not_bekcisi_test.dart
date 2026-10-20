// Tasarım kurulu tur 6 (Opus + Codex, ekranda doğrulandı): "Özel oda oluştur"
// sayfasında jeton yetmeyince
//
// * "N jeton eksik" notu kaydırılan içeriğin SONUNDA duruyordu; alt solmanın
//   (`SahneBottomFade`) altında kalıp düğmenin hemen üstünde soluk, kesik bir
//   satır olarak görünüyordu: yetmeme nedeni okunmuyordu.
// * Başlığın altında ayraç yoktu; kaydırılan çipler başlığın altından yarım
//   kesik bir sıra olarak görünüyordu.
//
// Niçin sessiz kaldı: mevcut testler notun VARLIĞINA bakıyordu (`findsOneWidget`),
// nerede durduğuna ve okunur olup olmadığına değil; kesik çizim yalnız ekran
// görüntüsünde görünür. Bu bekçi notun kaydırma alanının DIŞINDA, düğmenin
// hemen üstünde durduğunu ve başlık ayracının var olduğunu sabitler.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/screens/play_hub_screen.dart';

import 'support/widget_test_helpers.dart';

class _Repo extends MockZanKurdRepository {
  @override
  Future<int> loadCoinBalance() async => 10;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'jeton eksik notu kaydırma alanı dışında, düğmenin hemen üstünde',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        testShell(child: PlayHubScreen(repository: _Repo())),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('play-hub-create-room')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('custom-room-settings-row')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('custom-room-settings-row')));
      await tester.pumpAndSettle();
      final fee = find.byKey(const ValueKey('custom-room-fee-25'));
      await tester.ensureVisible(fee);
      await tester.pumpAndSettle();
      await tester.tap(fee);
      await tester.pumpAndSettle();

      final note = find.byKey(const ValueKey('custom-room-shortfall'));
      final button = find.byKey(const ValueKey('custom-room-open'));
      expect(note, findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('custom-room-bottom-fade')),
          matching: note,
        ),
        findsNothing,
        reason: 'Not solmanın altında kalıp kesik görünüyordu.',
      );
      final gap = tester.getTopLeft(button).dy - tester.getBottomLeft(note).dy;
      expect(
        gap,
        inInclusiveRange(0, 16),
        reason: 'Not düğmenin hemen üstünde.',
      );
      expect(
        find.byKey(const ValueKey('custom-room-header-divider')),
        findsOneWidget,
      );
    },
  );
}
