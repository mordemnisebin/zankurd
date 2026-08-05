import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/screens/home_screen.dart';
import 'package:zankurd_mobile/src/screens/shop_screen.dart';
import 'package:zankurd_mobile/src/theme/app_icons.dart';

import 'support/widget_test_helpers.dart';

/// Mağazaya giden yolun bekçisi.
///
/// 2026-07-27 denetimi: mağazaya tek giriş profil ekranının içindeydi.
/// Coin kazanan oyuncu onu nerede harcayacağını bulamıyordu — oysa ana
/// ekranın tepesinde bakiyeyi gösteren bir rozet zaten duruyor. Rozet
/// artık mağazayı açar.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'zankurd.onboarding.seen': true,
      'zankurd.profileName.completed.user': true,
      'zankurd.navTour.seen': true,
    });
  });

  testWidgets('coin rozeti mağazayı açar', (tester) async {
    await tester.pumpWidget(
      testShell(
        child: Scaffold(body: HomeScreen(repository: MockZanKurdRepository())),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.byIcon(AppIcons.coins));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byType(ShopScreen), findsOneWidget);
  });
}
