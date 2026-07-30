import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/widgets/responsive_wrapper.dart';

void main() {
  testWidgets('wide web layout reaches the desktop breakpoint', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    double? availableWidth;
    await tester.pumpWidget(
      MaterialApp(
        home: ResponsiveWrapper(
          child: LayoutBuilder(
            builder: (context, constraints) {
              availableWidth = constraints.maxWidth;
              return const SizedBox.expand();
            },
          ),
        ),
      ),
    );

    expect(availableWidth, greaterThanOrEqualTo(768));
  });

  test('privacy, wildcard and subscription copy stays truthful', () {
    final strings = File('lib/src/l10n/strings.dart').readAsStringSync();
    final wildcard = File('lib/src/models/wildcard.dart').readAsStringSync();
    final paywall = File(
      'lib/src/screens/paywall_screen.dart',
    ).readAsStringSync();
    final privacy = File('web/privacy.html').readAsStringSync();

    expect(
      strings,
      isNot(contains('Adın yalnızca liderlik tablosunda görünür')),
    );
    expect(strings, isNot(contains('Navê te tenê di tabloya pêşderçûnê de')));
    expect(privacy, isNot(contains('yalnızca liderlik tablosunda')));
    expect(privacy, isNot(contains('tenê di tabloya pêşderçûnê de')));
    expect(wildcard, isNot(contains('Seyirciye Sor')));
    expect(strings, isNot(contains('Seyirci oy dağılımını görürsün')));
    expect(paywall, isNot(contains('2 ay bedava')));
    expect(paywall, isNot(contains('2 meh belaş')));
    expect(paywall, isNot(contains('premium.errorMessage')));
    expect(paywall, isNot(contains('premium.infoMessage')));
  });

  test('solid accents use adaptive foregrounds and tap targets stay large', () {
    final expectedHelpers = <String, String>{
      'lib/src/widgets/mission_toast.dart': 'AppColors.onSolid(AppTheme.gold)',
      'lib/src/widgets/offline_banner.dart':
          'AppColors.onSolid(AppTheme.wrong)',
      'lib/src/screens/quiz_result_screen.dart':
          'AppColors.onSolid(AppTheme.gold)',
      'lib/src/screens/quiz/quiz_screen_ui.dart': 'AppColors.onSolid(',
      'lib/src/screens/paywall_screen.dart': 'AppColors.onSolid(',
    };
    for (final entry in expectedHelpers.entries) {
      expect(
        File(entry.key).readAsStringSync(),
        contains(entry.value),
        reason: '${entry.key} adaptive foreground kullanmıyor',
      );
    }

    expect(
      File('lib/src/widgets/styled_input.dart').readAsStringSync(),
      contains('minWidth: 44'),
    );
    expect(
      File('lib/src/widgets/legal_links.dart').readAsStringSync(),
      contains('minHeight: 44'),
    );
    expect(
      File('lib/src/widgets/offline_banner.dart').readAsStringSync(),
      contains('minHeight: 44'),
    );
  });
}
