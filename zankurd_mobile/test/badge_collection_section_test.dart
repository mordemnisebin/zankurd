import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/badge_service.dart';
import 'package:zankurd_mobile/src/widgets/badge_collection_section.dart';

import 'support/widget_test_helpers.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    BadgeService.resetInstance();
  });

  testWidgets('rozet koleksiyonu tümünü gör eylemi 44 px hedef taşır', (
    tester,
  ) async {
    await tester.pumpWidget(
      testShell(child: const Scaffold(body: BadgeCollectionSection())),
    );
    // BadgeWidget görsel animasyonları sürekli canlı tuttuğu için settle
    // yerine yüklenme işinin tamamlanacağı kadar kontrollü ilerle.
    await tester.pump(const Duration(seconds: 1));

    final button = find.byType(TextButton);
    expect(button, findsOneWidget);
    expect(tester.getSize(button).height, greaterThanOrEqualTo(44));
  });
}
