/// Ana sayfa: kırılan seri için açılış onarım sayfası (kırılma başına BİR kez).
///
/// ## Kusur
///
/// Seri son 24 saatte kırıldığında oyuncu yalnız rozetin kaybolduğunu
/// görüyordu; onarım teklifi hiçbir yerde sunulmuyordu.
///
/// ## Niçin sessiz kalırdı
///
/// Teklif depo durumundan türer ve sayfa açılışta kendiliğinden gelir; bir
/// ekran testi kırık seriyi kurup sayfanın gerçekten çıktığını (ve ikinci
/// açılışta ÇIKMADIĞINI) görmedikçe, sürekli rahatsız eden ya da hiç
/// görünmeyen bir teklif fark edilmezdi.
///
/// ## Kural
///
/// * Seri iki gün önce kırıldıysa ilk açılışta sayfa çıkar.
/// * "Şimdi değil"den sonra aynı kırılma için bir daha çıkmaz.
/// * Seri sağlamsa ya da hiç yoksa sayfa çıkmaz.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/data/streak_store.dart';
import 'package:zankurd_mobile/src/screens/home_screen.dart';

import 'support/widget_test_helpers.dart';

String _key(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

const _action = ValueKey('streak-repair-action');
const _later = ValueKey('streak-repair-later');

Future<void> _pumpHome(WidgetTester tester) async {
  await tester.pumpWidget(
    testShell(
      child: Scaffold(body: HomeScreen(repository: MockZanKurdRepository())),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();
}

void main() {
  final now = DateTime.now();
  final twoDaysAgo = DateTime(now.year, now.month, now.day - 2);
  final yesterday = DateTime(now.year, now.month, now.day - 1);

  Map<String, Object> seed({required DateTime lastDay, int current = 6}) => {
    'zankurd.onboarding.seen': true,
    'zankurd.profileName.completed.user': true,
    'zankurd.navTour.seen': true,
    'zankurd.streak.current': current,
    'zankurd.streak.best': current,
    'zankurd.streak.lastDay': _key(lastDay),
  };

  setUp(StreakStore.resetInstance);

  testWidgets('iki gün önce kırılan seri: ilk açılışta sayfa çıkar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues(seed(lastDay: twoDaysAgo));

    await _pumpHome(tester);

    expect(find.byKey(_action), findsOneWidget);
    expect(find.text('Serin bozuldu'), findsOneWidget);
  });

  testWidgets('"Şimdi değil"den sonra aynı kırılma için bir daha çıkmaz', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues(seed(lastDay: twoDaysAgo));

    await _pumpHome(tester);
    await tester.tap(find.byKey(_later));
    await tester.pumpAndSettle();
    expect(find.byKey(_action), findsNothing);

    // İkinci açılış: yeni ana sayfa, aynı yerel depo.
    await tester.pumpWidget(const SizedBox.shrink());
    await _pumpHome(tester);

    expect(find.byKey(_action), findsNothing);
  });

  testWidgets('seri sağlamsa (dün oynandı) sayfa çıkmaz', (tester) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues(seed(lastDay: yesterday));

    await _pumpHome(tester);

    expect(find.byKey(_action), findsNothing);
  });
}
