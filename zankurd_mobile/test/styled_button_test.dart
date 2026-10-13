import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zankurd_mobile/src/providers/reduced_motion_provider.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';
import 'package:zankurd_mobile/src/theme/sahne.dart';
import 'package:zankurd_mobile/src/widgets/sahne/sahne_foundation.dart';
import 'package:zankurd_mobile/src/widgets/styled_button.dart';

/// Birincil CTA (`GeometricGradientButton`) hover 1.01 ölçeğini ve 110 ms
/// basış gölgesini "hareketi azalt" varken yine oynatıyordu.
///
/// Ölçek ve süre süsüdür, durum taşımaz: tercih açıkken hareket durmalı.
/// Bu düğme yedi CTA'da kullanıldığı için ayarı yok saymak tercihi fiilen
/// işlevsiz bırakır.
///
/// 2026-09-29 Şahnê: düğme artık `SahneButton.primary` görünüşündedir —
/// hover büyümesi yok, basınca 2 px çöker (`SahnePressSink`). Eski hover
/// ölçeği bekçileri o görünüşü sabitliyordu; yerlerine korunan şeyin
/// kendisi gelir: hareketi azaltta çökme yok, Agir üstünde koyu metin
/// (beyaz 2,35:1 kalıyordu), yüklenirken basılamaz.
void main() {
  Future<Offset> pressAndReadSink(WidgetTester tester) async {
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(GeometricGradientButton)),
    );
    await tester.pump();
    final transform = tester.widget<Transform>(
      find.descendant(
        of: find.byType(SahnePressSink),
        matching: find.byType(Transform),
      ),
    );
    final offset = Offset(
      transform.transform.getTranslation().x,
      transform.transform.getTranslation().y,
    );
    await gesture.up();
    await tester.pump();
    return offset;
  }

  testWidgets('basınca 2 px çöker', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: GeometricGradientButton(label: 'Devam', onPressed: _noop),
        ),
      ),
    );
    expect(await pressAndReadSink(tester), const Offset(0, 2));
  });

  testWidgets('hareketi azalt açıkken basınca çökme yok', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => ReducedMotionProvider(initialUserReduce: true),
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(
            body: GeometricGradientButton(label: 'Devam', onPressed: _noop),
          ),
        ),
      ),
    );
    expect(await pressAndReadSink(tester), Offset.zero);
  });

  testWidgets('Agir üstünde metin koyu (onAct), beyaz değil', (tester) async {
    for (final theme in [AppTheme.light(), AppTheme.dark()]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: const Scaffold(
            body: GeometricGradientButton(label: 'Devam', onPressed: _noop),
          ),
        ),
      );
      final context = tester.element(find.text('Devam'));
      final t = SahneTokens.of(context);
      expect(DefaultTextStyle.of(context).style.color, t.onAct);
      expect(DefaultTextStyle.of(context).style.color, isNot(Colors.white));
    }
  });

  testWidgets('yüklenirken basılamaz ve ilerleme halkası koyudur', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: GeometricGradientButton(
            label: 'Devam',
            onPressed: _noop,
            isLoading: true,
          ),
        ),
      ),
    );

    final node = tester
        .getSemantics(find.bySemanticsLabel('Devam'))
        .getSemanticsData();
    expect(node.hasAction(SemanticsAction.tap), isFalse);
    final spinner = tester.widget<CircularProgressIndicator>(
      find.byType(CircularProgressIndicator),
    );
    expect(spinner.valueColor!.value, SahneTokens.day.onAct);
    handle.dispose();
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
