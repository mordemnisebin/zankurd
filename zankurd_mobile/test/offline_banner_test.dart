import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/widgets/offline_banner.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('offline banner retry action is tappable', (tester) async {
    var tapped = 0;

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => LanguageProvider(initialLang: 'tr'),
        child: MaterialApp(
          home: Scaffold(
            body: OfflineBanner(isOffline: true, onRetry: () => tapped++),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Tekrar dene'));
    await tester.pumpAndSettle();

    expect(tapped, 1);
  });

  testWidgets('offline banner hides itself when online', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => LanguageProvider(initialLang: 'tr'),
        child: const MaterialApp(
          home: Scaffold(body: OfflineBanner(isOffline: false)),
        ),
      ),
    );

    expect(
      find.text('İnternet bağlantısı yok — Kontrol ediliyor…'),
      findsNothing,
    );
  });
}
