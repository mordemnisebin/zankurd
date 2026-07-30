import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';
import 'package:zankurd_mobile/src/widgets/styled_input.dart';

void main() {
  testWidgets('ortak giriş alanı tema çerçevesini ikinci kez çizmez', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: StyledInputField(
            label: 'Navnîşana e-peyamê',
            controller: controller,
            prefixIcon: Icons.email_outlined,
          ),
        ),
      ),
    );

    final decoration = tester
        .widget<TextField>(find.byType(TextField))
        .decoration;
    expect(decoration?.border, InputBorder.none);
    expect(decoration?.enabledBorder, InputBorder.none);
    expect(decoration?.focusedBorder, InputBorder.none);
    expect(decoration?.disabledBorder, InputBorder.none);
    expect(decoration?.errorBorder, InputBorder.none);
    expect(decoration?.focusedErrorBorder, InputBorder.none);
    expect(decoration?.filled, isFalse);
  });
}
