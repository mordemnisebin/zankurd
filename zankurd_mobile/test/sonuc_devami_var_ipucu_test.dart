/// Sonuç listesi altta devam ediyorsa bunu söyler; profil ayrıntısı açılınca
/// görünür alana gelir; misafir arkadaş seçimi boş durum gösterir.
///
/// ## Kusurlar (simülatör turu 5, 2026-11-04)
///
/// - Günün turu sonucunda "Hat qezenckirin" kartının altı alt perdenin
///   arkasında düz kesikti; liste kaydırılabiliyordu ama bunu hiçbir şey
///   söylemiyordu (16_daily_result).
/// - Profilde "Statîstîkên berfireh" paneli altı karonun ARKASINDA açılıyor,
///   ilk ekranda hiçbir şey değişmiyordu; üç dokunuş aç/kapat/aç oldu.
/// - Oda sonucunda "Rêzbendiya pêşbirkê" başlığın altı boştu: sığmayan
///   satırlar `WholeScrollRow` ile gizleniyordu.
///
/// ## Niçin sessiz kaldı
///
/// Testler 390x844'ten uzun içerikte alt kenarı ve ayrıntı panelinin ilk
/// ekranda görünüp görünmediğini ölçmüyordu.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mastery_store.dart';
import 'package:zankurd_mobile/src/data/mistake_store.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/friend.dart';
import 'package:zankurd_mobile/src/screens/async_duel/async_duel_challenge_sheet.dart';
import 'package:zankurd_mobile/src/screens/profile_screen.dart';
import 'package:zankurd_mobile/src/widgets/sahne/sahne.dart';

import 'support/widget_test_helpers.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('uzun sonuç: "aşağı" düğmesi görünür ve sona kaydırır', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(375, 667);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      testShell(
        child: SahneResultScaffold(
          hero: const SahneResultHero(
            emblem: SizedBox(height: 44),
            title: 'Bitti',
            value: 7,
            caption: 'puan',
          ),
          stats: const SahneResultStats(
            stats: [
              SahneResultStat(
                leading: SizedBox(),
                value: 2,
                label: 'Doğru',
                showWhenZero: true,
              ),
            ],
          ),
          rewards: const SahneResultRewards(coins: 30, xp: 100),
          sections: [
            for (var i = 0; i < 12; i++)
              SizedBox(height: 60, child: Text('satır $i')),
            const Text('SON', key: ValueKey('son')),
          ],
          primary: SahneResultAction(label: 'Tamam', onPressed: () {}),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final ipucu = find.byKey(const ValueKey('result-more-below'));
    expect(ipucu, findsOneWidget);
    await tester.tap(ipucu);
    await tester.pumpAndSettle();
    expect(ipucu, findsNothing, reason: 'Sona gelince ipucu kalkar.');
    expect(find.byKey(const ValueKey('son')).hitTestable(), findsOneWidget);
  });

  testWidgets('kısa sonuç: "aşağı" düğmesi çizilmez', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      testShell(
        child: SahneResultScaffold(
          hero: const SahneResultHero(
            emblem: SizedBox(height: 44),
            title: 'Bitti',
            value: 7,
          ),
          sections: const [Text('bölüm'), Text('bir daha')],
          stats: const SahneResultStats(
            stats: [
              SahneResultStat(
                leading: SizedBox(),
                value: 1,
                label: 'Doğru',
                showWhenZero: true,
              ),
            ],
          ),
          primary: SahneResultAction(label: 'Tamam', onPressed: () {}),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('result-more-below')), findsNothing);
  });

  testWidgets('profil: "Ayrıntılı istatistik" paneli ilk ekranda görünür', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    MasteryStore.resetInstance();
    MistakeStore.resetInstance();
    SharedPreferences.setMockInitialValues({
      'zankurd.mastery.Ziman': 120,
      'zankurd.mastery.Çand': 20,
    });
    final hatalar = await MistakeStore.load();
    await hatalar.markMistake('p-c1', category: 'Cografya');
    await tester.pumpWidget(
      testShell(
        child: Scaffold(
          body: ProfileScreen(repository: MockZanKurdRepository()),
        ),
      ),
    );
    for (
      var i = 0;
      i < 40 && find.text('Ayrıntılı istatistik').evaluate().isEmpty;
      i++
    ) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    final baglanti = find.text('Ayrıntılı istatistik');
    // Bağlantı ekranın altında dururken dokunulur (telefonda olduğu gibi).
    await Scrollable.ensureVisible(tester.element(baglanti), alignment: 0.8);
    await tester.pumpAndSettle();
    await tester.tap(baglanti);
    await tester.pumpAndSettle();
    final panel = find.byKey(const ValueKey('profile-detailed-stats'));
    expect(panel, findsOneWidget);
    final ust = tester.getTopLeft(panel).dy;
    expect(
      ust,
      lessThan(300),
      reason: 'Panel açılınca görünür alana kaymalı (üst kenar $ust).',
    );
  });

  testWidgets('misafir arkadaş seçimi sunucuya sormadan boş durumu gösterir', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    final repo = _AskmazDepo();
    await tester.pumpWidget(
      testShell(
        authProvider: _MisafirAuth(),
        child: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showAsyncDuelChallengeSheet(context, repo),
              child: const Text('aç'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('aç'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('challenge-sheet-friend')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('challenge-friends-empty')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('challenge-friends-empty-link')),
      findsOneWidget,
    );
    expect(repo.cagri, 0, reason: 'Misafir için arkadaş sorgusu atılmaz.');
  });
}

class _MisafirAuth extends FakeAuthProvider {
  @override
  bool get isGuest => true;
}

class _AskmazDepo extends MockZanKurdRepository {
  int cagri = 0;

  @override
  Future<List<Friend>> loadFriends() {
    cagri++;
    return Future<List<Friend>>.delayed(const Duration(days: 1));
  }
}
