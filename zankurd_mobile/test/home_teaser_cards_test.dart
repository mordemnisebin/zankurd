// 2026-07-23 canlı UX denetimi: ana sayfadaki "Kategoriler" ve "Hemen oyna"
// geçiş kartları ekran okuyucuda çift okunuyordu — dıştaki Semantics(label:)
// ile içteki başlık Text'i birleşiyordu (M28 devamı, colorful_action_card.dart
// ile aynı kök neden).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/screens/home/categories_teaser_card.dart';
import 'package:zankurd_mobile/src/screens/home/play_teaser_card.dart';

Widget wrap(Widget child) => MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => LanguageProvider()..setLang('tr')),
  ],
  child: MaterialApp(home: Scaffold(body: child)),
);

void main() {
  testWidgets('kategoriler teaser kartı çift okunmaz', (tester) async {
    final handle = tester.ensureSemantics();
    var tapped = false;
    await tester.pumpWidget(
      wrap(CategoriesTeaserCard(onTap: () => tapped = true)),
    );

    expect(find.bySemanticsLabel('Kategoriler'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('home-categories-teaser')));
    expect(tapped, isTrue);
    handle.dispose();
  });

  testWidgets('hemen oyna teaser kartı çift okunmaz', (tester) async {
    final handle = tester.ensureSemantics();
    var tapped = false;
    await tester.pumpWidget(wrap(PlayTeaserCard(onTap: () => tapped = true)));

    expect(find.bySemanticsLabel('Hemen oyna'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('home-play-teaser')));
    expect(tapped, isTrue);
    handle.dispose();
  });
}
