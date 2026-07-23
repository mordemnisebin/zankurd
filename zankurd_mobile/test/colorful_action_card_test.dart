import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';
import 'package:zankurd_mobile/src/widgets/colorful_action_card.dart';

void main() {
  testWidgets('ColorfulActionCard renders and invokes callback', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ColorfulActionCard(
            title: '1 vs 1',
            subtitle: 'Hemen oyna',
            icon: Icons.bolt_rounded,
            colors: const [AppTheme.playPink, Color(0xFFFF6B70)],
            onTap: () => taps++,
          ),
        ),
      ),
    );

    expect(find.text('1 vs 1'), findsOneWidget);
    expect(find.text('Hemen oyna'), findsOneWidget);
    await tester.tap(find.text('1 vs 1'));
    expect(taps, 1);
  });

  // 2026-07-23 canlı UX denetimi: Pêşbazî mod kartları ekran okuyucuda
  // "Şerê 1vs1 Şerê 1vs1 Bot + Zindî" gibi çift okunuyordu — dıştaki
  // Semantics(label:) ile içteki başlık Text'i birleşiyordu.
  testWidgets('semantics label başlığı çift okumaz, alt başlığı içerir', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ColorfulActionCard(
            title: 'Şerê 1vs1',
            subtitle: 'Bot + Zindî',
            icon: Icons.bolt_rounded,
            colors: const [AppTheme.playPink, Color(0xFFFF6B70)],
            onTap: () {},
          ),
        ),
      ),
    );

    expect(find.bySemanticsLabel('Şerê 1vs1. Bot + Zindî'), findsOneWidget);
    // Görünür Text içeriği kendi semantics düğümünü eklemesin diye
    // ExcludeSemantics ile dışlandığından, "Şerê 1vs1" tek bir düğümde
    // (dıştaki label) bulunmalı — metnin kendisi ayrıca bulunmamalı.
    expect(find.bySemanticsLabel('Şerê 1vs1'), findsNothing);
    handle.dispose();
  });

  testWidgets('loading card ignores taps and shows progress', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ColorfulActionCard(
            title: 'Günün Yarışması',
            icon: Icons.emoji_events_rounded,
            colors: const [AppTheme.brand, AppTheme.brandDeep],
            loading: true,
            onTap: () => tapped = true,
          ),
        ),
      ),
    );
    await tester.tap(find.text('Günün Yarışması'));
    expect(tapped, isFalse);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
