import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zankurd_mobile/src/providers/reduced_motion_provider.dart';
import 'package:zankurd_mobile/src/widgets/styled_button.dart';

/// Birincil CTA (`GeometricGradientButton`) hover 1.01 ölçeğini ve 110 ms
/// basış gölgesini "hareketi azalt" varken yine oynatıyordu.
///
/// Ölçek ve süre süsüdür, durum taşımaz: tercih açıkken 1.0 / sıfır sürede
/// durmalı. Zıplayan düğme aynı kapıdan geçiyor; bu düğme yedi CTA'da
/// kullanıldığı için ayarı yok saymak tercihi fiilen işlevsiz bırakır.
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

  testWidgets('hareketi azalt açıkken hover ölçeği yok', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => ReducedMotionProvider(initialUserReduce: true),
        child: const MaterialApp(
          home: Scaffold(
            body: GeometricGradientButton(label: 'Devam', onPressed: _noop),
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
    expect(scale.duration, Duration.zero);
    final container = tester.widget<AnimatedContainer>(
      find.byType(AnimatedContainer),
    );
    expect(container.duration, Duration.zero);
  });

  testWidgets('enabled geometric button exposes a tap action', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: GeometricGradientButton(label: 'Devam', onPressed: _noop),
        ),
      ),
    );

    final node = tester
        .getSemantics(find.bySemanticsLabel('Devam'))
        .getSemanticsData();
    expect(node.hasAction(SemanticsAction.tap), isTrue);
    handle.dispose();
  });
}

void _noop() {}
