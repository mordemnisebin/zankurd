import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/widgets/styled_button.dart';

void main() {
  testWidgets('enabled geometric button grows slightly on hover', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: GeometricGradientButton(label: 'Devam', onPressed: _noop),
        ),
      ),
    );

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(gesture.removePointer);
    await gesture.addPointer(location: const Offset(1, 1));
    await gesture.moveTo(
      tester.getCenter(find.byType(GeometricGradientButton)),
    );
    await tester.pump(const Duration(milliseconds: 150));

    final scale = tester.widget<AnimatedScale>(find.byType(AnimatedScale));
    expect(scale.scale, 1.01);
  });

  testWidgets('loading geometric button does not keep hover scale', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: GeometricGradientButton(
            label: 'Devam',
            onPressed: _noop,
            isLoading: true,
          ),
        ),
      ),
    );

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(gesture.removePointer);
    await gesture.addPointer(location: const Offset(1, 1));
    await gesture.moveTo(
      tester.getCenter(find.byType(GeometricGradientButton)),
    );
    await tester.pump(const Duration(milliseconds: 150));

    final scale = tester.widget<AnimatedScale>(find.byType(AnimatedScale));
    expect(scale.scale, 1.0);
  });
}

void _noop() {}
