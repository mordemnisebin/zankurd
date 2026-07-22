import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/screens/app_shell.dart';
import 'package:zankurd_mobile/src/widgets/coach_mark.dart';

import 'support/widget_test_helpers.dart';

void main() {
  Future<void> pumpTour(WidgetTester tester) async {
    await tester.pumpWidget(
      testShell(child: AppShell(repository: MockZanKurdRepository())),
    );
    await tester.pumpAndSettle();
  }

  test(
    'nav turu iki adım taşır ve tamamlanınca mevcut seen anahtarını yazar',
    () {
      final source = File('lib/src/screens/app_shell.dart').readAsStringSync();

      expect(RegExp(r'CoachMarkStep\(').allMatches(source), hasLength(2));
      expect(source, contains("titleKu: 'Sereke'"));
      expect(source, contains("titleTr: 'Ana Sayfa'"));
      expect(source, contains("titleKu: 'Pêşbazî'"));
      expect(source, contains("titleTr: 'Oyna'"));
      expect(source, isNot(contains("titleTr: 'Profil'")));
      expect(source, contains('onFinished: _finishNavTour'));
      expect(source, contains('setBool(_navTourSeenKey, true)'));
    },
  );

  testWidgets('nav turu atlanınca görülmüş kalır ve tekrar açılmaz', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({
      'zankurd.onboarding.seen': true,
      'zankurd.profileName.completed': true,
    });
    await pumpTour(tester);
    await tester.tap(find.text('Atla'));
    await tester.pumpAndSettle();
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getBool('zankurd.navTour.seen'), isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await pumpTour(tester);
    expect(find.byType(CoachMarkOverlay), findsNothing);
  });
}
