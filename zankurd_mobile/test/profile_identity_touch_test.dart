// 2026-09-29 doğallık: arayüz metni sabitleyen beklentiler yeni metne göre güncellendi.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mistake_store.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/leaderboard_entry.dart';
import 'package:zankurd_mobile/src/screens/profile_screen.dart';
import 'package:zankurd_mobile/src/theme/app_icons.dart';
import 'package:zankurd_mobile/src/widgets/sahne/sahne.dart';
import 'package:zankurd_mobile/src/theme/kilim_motifs.dart';
import 'package:zankurd_mobile/src/widgets/arena_kit.dart';
import 'package:zankurd_mobile/src/widgets/rolling_count.dart';

import 'support/widget_test_helpers.dart';

/// Profil ekranı "beyaz kart yığını" olarak okunuyordu: kimlik kartının
/// altındaki her şey birbirinin aynı beyaz kutu. Bu bekçi üç kimlik
/// dokunuşunun sessizce geri alınmasını engeller: kimlik kartının altında
/// tek kilim bordürü, başarılar `MissionProgressCard`, istatistik sayıları
/// `RollingCount` (2026-08-19).
///
/// Kusur niçin sessiz kalmıştı: profil testleri yalnız VERİ doğruluğuna
/// bakıyordu (kaç soru cevaplandı, rozet şişirildi mi). Görsel dilin hangi
/// bileşenle çizildiği hiç denetlenmiyordu — beyaz kutu olup olmadığı
/// simülatörün konusu sanılıyordu.
///
/// 2026-08-19 review: hero rozetine `RankMedal` de eklenmişti ama o madalya
/// sıra NUMARASINI basıp aşağıdaki "Sıra" karosuyla aynı şeyi iki kez
/// söylüyor, tonu da lig etiketiyle çelişiyordu (sıra 3 → bronz madalya +
/// "Altın lig"). Hero artık yalnız lig etiketi + tier ikonu gösterir; sıra
/// rakamı tek yerde (Sıra karosu) kalır.
///
/// 2026-09-29 Şahnê: yeşil kahraman kart, kilim bordürü ve
/// `MissionProgressCard` kalktı. Kimlik sayfa zemininde elmas avatar + ad
/// + kod; başarılar Zêr ilerleme çubuklu yüzey kartı; kamera rozeti Kulis
/// tonlu küçük elmas. Bekçiler yeni dile göre güncellendi.
class _RankedRepo extends MockZanKurdRepository {
  @override
  Future<LeaderboardEntry?> getPlayerStats() async => const LeaderboardEntry(
    rank: 2,
    playerId: 'me',
    displayName: 'Baran',
    totalScore: 7190,
    bestStreak: 9,
    roomsPlayed: 12,
  );
}

/// Bir yanlış + bir doğru cevap kaydı → `_answeredTotal = 2`. Böylece
/// istatistik karoları (ve puanlı durumda sıralama kapısı) boş duruma
/// düşmez; karolar gerçekten çizilir.
Future<void> _seedMistakes() async {
  MistakeStore.resetInstance();
  SharedPreferences.setMockInitialValues({});
  final store = await MistakeStore.load();
  await store.markMistake('rank-q1', category: 'Ziman');
  await store.markResolved('rank-q1');
}

/// Profil yüklenene kadar pompalar; yükleme bittiğinde sinyali [loaded]
/// bulunur. `pumpAndSettle` kullanılmaz: profil mağaza yüklemeleri asenkron
/// ve birbirine zincirli olduğu için sabit süreli tur daha güvenilirdir.
Future<void> _pumpLoaded(
  WidgetTester tester,
  MockZanKurdRepository repo,
) async {
  await tester.pumpWidget(
    testShell(
      child: Scaffold(body: ProfileScreen(repository: repo)),
    ),
  );
  await tester.pump();
  final loaded = find.byKey(const ValueKey('profile-rewards-card'));
  for (var i = 0; i < 40 && loaded.evaluate().isEmpty; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  await tester.pump(const Duration(milliseconds: 200));
}

void main() {
  testWidgets('profil avatar düzenleme rozeti Kulis elmasıdır', (tester) async {
    await _seedMistakes();
    await _pumpLoaded(tester, _RankedRepo());

    final badge = tester.widget<DecoratedBox>(
      find
          .ancestor(
            of: find.byIcon(AppIcons.camera),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    final decoration = badge.decoration as ShapeDecoration;
    final t = SahneTokens.of(tester.element(find.byIcon(AppIcons.camera)));
    expect(decoration.color, t.s2);
    expect(decoration.shape, isA<BeveledRectangleBorder>());
    expect(find.byKey(const ValueKey('profile-avatar-edit')), findsOneWidget);
  });

  testWidgets('profil kimlik dokunuşlarını taşır', (tester) async {
    await _seedMistakes();
    await _pumpLoaded(tester, _RankedRepo());
    expect(tester.takeException(), isNull);

    // Büyük kilim bordürü yok: kilim yalnız göz şeridinde yaşar.
    expect(find.byType(KilimDivider), findsNothing);
    // "Başarılar X/Y" Zêr ilerleme çubuklu yüzey kartı.
    final rewards = find.byKey(const ValueKey('profile-rewards-card'));
    expect(rewards, findsOneWidget);
    final bar = tester.widget<SahneProgressBar>(
      find.descendant(of: rewards, matching: find.byType(SahneProgressBar)),
    );
    expect(bar.tone, SahneProgressTone.gold);
    // Sayısal istatistikler RollingCount ile sayar.
    expect(find.byType(RollingCount), findsWidgets);
    // Sıra NUMARASI kimlikte madalya olarak çizilmez; rakam yalnız Sıra
    // karosunda kalır.
    expect(find.byType(RankMedal), findsNothing);
  });
}
