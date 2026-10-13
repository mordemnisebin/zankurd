/// Profilin boş istatistik durumu: bağlamsal ikon + tek cümle + tek eylem.
///
/// ## Kusur
///
/// Hiç soru çözmemiş oyuncunun profilinde istatistik kartı gri bir cümle
/// ve bir düğmeden ibaretti; profilin en boş anı en renksiz anıydı
/// (2026-09-28). O gün metnin yanına "düşünceli" maskot kondu.
///
/// 2026-09-29 doğallık (K3): boş durumların ortak dili logo/maskot plakası
/// değil, 32'lik üçüncül bir bağlamsal çizgi ikondur (burada istatistik
/// sütunu) + metin + tek eylem. Maskot plakası üretilmiş görsel izi
/// taşıyordu; logo marka satırının işidir.
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
import 'package:zankurd_mobile/src/theme/app_icons.dart';
import 'package:zankurd_mobile/src/widgets/roj_mascot.dart';
import 'package:zankurd_mobile/src/widgets/sahne/sahne.dart';

import 'support/widget_test_helpers.dart';

void main() {
  tearDown(() async => SyncManager.resetForTesting());

  testWidgets('boş istatistikte bağlamsal ikon ve başla düğmesi durur', (
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
    expect(
      find.descendant(of: row, matching: find.byType(RojMascot)),
      findsNothing,
      reason: 'boş durumda maskot/logo plakası yok',
    );
    final icon = find.descendant(
      of: row,
      matching: find.byIcon(AppIcons.chartColumn),
    );
    expect(icon, findsOneWidget);
    final iconWidget = tester.widget<Icon>(icon);
    expect(iconWidget.size, 32);
    expect(iconWidget.color, SahneTokens.of(tester.element(icon)).tx3);
    expect(
      find.ancestor(of: icon, matching: find.byType(ExcludeSemantics)),
      findsWidgets,
      reason: 'ikon semantik ağaca ayrı bir düğüm eklememeli',
    );
  });

  testWidgets('ilk turdan önce seviye kartı ve başarı çubuğu yok', (
    tester,
  ) async {
    // 2026-09-29 doğallık (K6): "Seviye 1 · 0/1000" ve "0/13" iki boş
    // sayaçtı; ilk turdan önce gizlenir. Başarılar kartı yalnız ilk
    // başarının nasıl açılacağını söyler.
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      testShell(
        child: Scaffold(
          body: ProfileScreen(repository: MockZanKurdRepository()),
        ),
      ),
    );
    final rewards = find.byKey(const ValueKey('profile-rewards-card'));
    for (var i = 0; i < 40 && rewards.evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(rewards, findsOneWidget);
    expect(find.byKey(const ValueKey('profile-level-card')), findsNothing);
    expect(
      find.descendant(of: rewards, matching: find.byType(SahneProgressBar)),
      findsNothing,
    );
    expect(find.text('İlk başarın için bir yarış bitir.'), findsOneWidget);
  });
}
