import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/providers/sound_provider.dart';
import 'package:zankurd_mobile/src/screens/tournament_screen.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockZanKurdRepository repository;

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'zankurd.quiz_tutorial.seen': true,
    });
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

      expect(find.text('Bot turnuva · günlük kupa'), findsOneWidget);
      expect(find.text('Turnuvaya Katıl'), findsOneWidget);
      final startButton = tester.widget<FilledButton>(
        find.byKey(const ValueKey('tournament-primary-cta')),
      );
      expect(
        startButton.style?.backgroundColor?.resolve({}),
        AppTheme.brandOrange,
      );
      expect(find.byIcon(Icons.emoji_events_rounded), findsAtLeast(1));
    });

    testWidgets('baslangic butonuna basildiginda son 16 eslesmesi yukleniyor', (
      tester,
    ) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(const ValueKey('tournament-primary-cta')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('tournament-primary-cta')));
      await tester.pumpAndSettle();

      // 16 oyunculu kupada ilk tur "Son 16"dır.
      expect(find.text('Son 16'), findsAtLeast(1));
      expect(find.text('Maçı Başlat'), findsOneWidget);
      // ScreenSectionLabel uppercase sunum kullanır.
      expect(find.text('TURNUVA ŞEMASI'), findsOneWidget);
    });
  });
}
