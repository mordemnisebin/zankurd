import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/providers/sound_provider.dart';
import 'package:zankurd_mobile/src/screens/tournament_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockZanKurdRepository repository;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    repository = MockZanKurdRepository();
  });

  Widget createTestWidget() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<SoundProvider>(create: (_) => SoundProvider()),
        ChangeNotifierProvider<LanguageProvider>(
          create: (_) => LanguageProvider(initialLang: 'tr'),
        ),
      ],
      child: MaterialApp(home: TournamentScreen(repository: repository)),
    );
  }

  group('TournamentScreen Tests', () {
    testWidgets('lobi ekrani dogru sekilde yukleniyor', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('ZanKurd Kupası'), findsOneWidget);
      expect(find.text('Turnuvaya Başla'), findsOneWidget);
      expect(find.byIcon(Icons.emoji_events_rounded), findsOneWidget);
    });

    testWidgets(
      'baslangic butonuna basildiginda ceyrek final eslesmesi yukleniyor',
      (tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        final startButton = find.text('Turnuvaya Başla');
        await tester.tap(startButton);
        await tester.pumpAndSettle();

        expect(find.text('Çeyrek Final'), findsAtLeast(1));
        expect(find.text('Maçı Başlat'), findsOneWidget);
        expect(find.text('Turnuva Şeması'), findsOneWidget);
      },
    );
  });
}
