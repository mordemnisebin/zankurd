import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';
import 'package:zankurd_mobile/src/widgets/reference_mode_card.dart';

void main() {
  testWidgets('referans mod kartı başlık, ilerleme ve eylem taşır', (
    tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: ReferenceModeCard(
            title: 'Ziman',
            subtitle: 'Rêziman û ferhenga Kurmancî',
            icon: Icons.menu_book_rounded,
            accent: AppTheme.brandOrange,
            progress: .4,
            onTap: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.text('Ziman'), findsOneWidget);
    expect(find.text('Rêziman û ferhenga Kurmancî'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);

    await tester.tap(find.text('Ziman'));
    expect(tapped, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('yüklenirken kart dokunmayı engeller', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: ReferenceModeCard(
            title: 'Pêşbirka Rojê',
            subtitle: '10 pirs',
            icon: Icons.today_rounded,
            accent: AppTheme.playPurple,
            loading: true,
            onTap: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(find.text('Pêşbirka Rojê'));
    expect(tapped, isFalse);
  });
}
