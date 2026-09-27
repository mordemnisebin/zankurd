/// Profilin boş istatistik durumu Zana ile karşılar.
///
/// ## Kusur
///
/// Hiç soru çözmemiş oyuncunun profilinde istatistik kartı gri bir cümle
/// ve bir düğmeden ibaretti; profilin en boş anı en renksiz anıydı
/// (2026-09-28). Maskot, belgesinde boş durumlar için tanımlanan
/// "düşünceli" hâliyle metnin yanında durur.
///
/// ## Niçin sessiz kalırdı
///
/// Profil testleri boş durumda yalnız düğmenin varlığına bakıyordu; kartın
/// ne gösterdiği ölçülmüyordu.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/data/sync_manager.dart';
import 'package:zankurd_mobile/src/screens/profile_screen.dart';
import 'package:zankurd_mobile/src/widgets/roj_mascot.dart';

import 'support/widget_test_helpers.dart';

void main() {
  tearDown(() async => SyncManager.resetForTesting());

  testWidgets('boş istatistikte düşünceli Zana ve başla düğmesi durur', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      testShell(
        child: Scaffold(
          body: ProfileScreen(repository: MockZanKurdRepository()),
        ),
      ),
    );
    final cta = find.byKey(const ValueKey('profile-stats-start-cta'));
    for (var i = 0; i < 40 && cta.evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(cta, findsOneWidget);

    final row = find.ancestor(of: cta, matching: find.byType(Row)).first;
    final mascot = find.descendant(of: row, matching: find.byType(RojMascot));
    expect(mascot, findsOneWidget);
    expect(tester.widget<RojMascot>(mascot).mood, RojMood.thinking);
    expect(
      find.ancestor(of: mascot, matching: find.byType(ExcludeSemantics)),
      findsWidgets,
      reason: 'maskot semantik ağaca ayrı bir düğüm eklememeli',
    );
  });
}
