import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';
import 'package:zankurd_mobile/src/widgets/share_story_card.dart';

/// Hikâye/kare paylaşım görseli iki biçimde ve iki dilde taşmadan çizilir.
/// Taşma kırmızı-sarı bantla PNG'ye girerdi ve paylaşan bunu görmezdi;
/// test ortamında taşma istisna olduğundan burada yakalanır.
void main() {
  for (final format in ShareCardFormat.values) {
    for (final isKu in [false, true]) {
      testWidgets('${format.name} ${isKu ? 'KU' : 'TR'} taşmadan çizilir', (
        tester,
      ) async {
        tester.view.physicalSize = Size(format.width, format.height);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: ShareStoryCard(
                isKu: isKu,
                format: format,
                scoreText: '9/10',
                category: 'Ziman',
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        expect(find.text('zankurd.com'), findsOneWidget);
      });
    }
  }
}
