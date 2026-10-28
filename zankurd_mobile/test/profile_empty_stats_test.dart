// 2026-10-28 tur 4 (U4): yeni oyuncuda dört boş bölüm TEK "Başlangıç" kartında toplandı.
// Kurul 5. tur 2026-10-20: seviye+XP+jeton kimlik başlığında; boş durumda "Adını belirle" ve birincil başla düğmesi.
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

    // U4 (2026-10-28 tur 4): boş istatistik/rekor/başarı bölümleri TEK
    // "Başlangıç" kartında: küçük rozet (kupa) + tek cümle + tek eylem. Eski
    // 20'lik grafik ikonlu şerit ve ayrı boş kartlar kalktı.
    final card = find.byKey(const ValueKey('profile-start-card'));
    expect(card, findsOneWidget);
    expect(
      find.descendant(of: card, matching: find.byType(RojMascot)),
      findsNothing,
      reason: 'boş durumda maskot/logo plakası yok',
    );
    final icon = find.descendant(
      of: card,
      matching: find.byIcon(AppIcons.trophy),
    );
    expect(icon, findsOneWidget);
    expect(
      find.ancestor(of: icon, matching: find.byType(ExcludeSemantics)),
      findsWidgets,
      reason: 'ikon semantik ağaca ayrı bir düğüm eklememeli',
    );
    expect(find.byIcon(AppIcons.chartColumn), findsNothing);
    expect(find.text('Henüz soru çözmedin.'), findsNothing);
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
    final card = find.byKey(const ValueKey('profile-start-card'));
    for (var i = 0; i < 40 && card.evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(card, findsOneWidget);
    // U4: boş Başarılar kartı ("0/13", ipucu) ayrı çizilmez.
    expect(find.byKey(const ValueKey('profile-rewards-card')), findsNothing);
    // Kurul 5. tur 2026-10-20: seviye + XP kimlik başlığına taşındı.
    expect(find.byKey(const ValueKey('profile-set-name-cta')), findsOneWidget);
    expect(find.byType(SahneProgressBar), findsOneWidget);
    expect(find.text('İlk başarın için bir yarış bitir.'), findsNothing);
  });
}
