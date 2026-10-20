// 7. tasarım kurulu (2026-10-20; Opus + Grok): ad yokken profil kimlik
// bloğunda başlık yerinde "Oyundaki adını gir ›" bağlantısı duruyor, seviye
// çubuğu 4 px ve jeton "0" çubuğa sıkışık duruyordu.
//
// ## Niçin sessiz kalırdı
//
// Eylem çalışıyordu (düğme var, ayarlara götürüyordu) ve eski bekçi yalnız
// onun varlığını sayıyordu; başlığın bir bağlantı mı kimlik mi olduğunu,
// çubuğun kalınlığını ve jetonun ayrı hap olup olmadığını hiçbir test
// sormuyordu. Bekçi: ad yokken başlık "Oyuncu ZK-…" metnidir ve bağlantı
// kalemli eylem olarak altındadır; çubuk 8 px; jeton ayrı hap.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/data/sync_manager.dart';
import 'package:zankurd_mobile/src/screens/profile_screen.dart';
import 'package:zankurd_mobile/src/theme/app_icons.dart';
import 'package:zankurd_mobile/src/widgets/sahne/sahne.dart';

import 'support/widget_test_helpers.dart';

class _TagRepo extends MockZanKurdRepository {
  @override
  Future<String?> getPlayerTag() async => '4F7K';
}

void main() {
  tearDown(() async => SyncManager.resetForTesting());

  testWidgets('adsız profilde başlık "Oyuncu ZK-…", kalemli eylem altında', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      testShell(
        child: Scaffold(body: ProfileScreen(repository: _TagRepo())),
      ),
    );
    final cta = find.byKey(const ValueKey('profile-set-name-cta'));
    for (var i = 0; i < 40 && cta.evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(cta, findsOneWidget);

    final title = find.text('Oyuncu ZK-4F7K');
    expect(title, findsOneWidget);
    // Başlık eylemin ÜSTÜNDE; eylem kalem ikonu taşır.
    expect(tester.getTopLeft(title).dy, lessThan(tester.getTopLeft(cta).dy));
    expect(
      find.descendant(of: cta, matching: find.byIcon(AppIcons.pen)),
      findsOneWidget,
    );

    // Seviye çubuğu 8 px; jeton ayrı hap.
    final bar = tester.widget<SahneProgressBar>(find.byType(SahneProgressBar));
    expect(bar.height, 8);
    expect(find.byKey(const ValueKey('profile-coin-pill')), findsOneWidget);
  });
}
