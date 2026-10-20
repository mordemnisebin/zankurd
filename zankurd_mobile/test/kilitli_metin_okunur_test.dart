// 2026-10-20 TASARIM KURULU (tur 6b): kilitli/pasif satır metni okunur.
//
// ## Kusur
//
// Kilitli ders ve seviye satırları ikincil metin ×0,6 SAYDAMLIKLA
// çiziliyordu (kurul 2. tur kararı: "kilitli açıkla aynı koyulukta
// okunuyordu"). Düzeltme fazla gitti: gündüz kartta başlıklar silik bir
// griye iniyordu, kilitli ders adları okunmuyordu (2 denetçi). Ayrıca
// "Asta xwe bibîne" kartının gövde metni sağ kenara değiyordu (sağ iç
// boşluk 8'di).
//
// ## Niçin sessiz kalırdı
//
// Eski bekçi saydamlığın 0,6 OLDUĞUNU sabitliyordu (kusuru koruyordu);
// metnin kontrastını ölçen yoktu. Sözleşme: kilitli metin saydamlıkla değil
// `SahneTokens.disabledFg` belirteciyle boyanır ve her iki temada yüzey
// üstünde WCAG AA (4.5) geçer; kilit ikonu kalır; saydamlık katmanı yoktur.
// Yerleşim: "Asta xwe bibîne" şeridinde eylem metni karta 16 pt'den yakın değildir.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/level_progress_store.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/data/placement_store.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/screens/learning_screen.dart';
import 'package:zankurd_mobile/src/screens/level_screen.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';
import 'package:zankurd_mobile/src/widgets/sahne/sahne.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

Widget _app(Widget home, {bool dark = false, String lang = 'tr'}) =>
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => LanguageProvider()..setLang(lang),
        ),
      ],
      child: MaterialApp(
        theme: dark ? AppTheme.dark() : AppTheme.light(),
        home: home,
      ),
    );

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    LevelProgressStore.resetInstance();
    PlacementStore.resetInstance();
  });

  for (final dark in [false, true]) {
    final t = dark ? SahneTokens.night : SahneTokens.day;
    final name = dark ? 'koyu' : 'açık';

    test('kilitli metin yüzey üstünde AA geçer ($name)', () {
      expect(_contrast(t.disabledFg, t.s1), greaterThanOrEqualTo(4.5));
    });

    testWidgets('kilitli seviye: belirteç rengi, saydamlık yok ($name)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          LevelScreen(repository: MockZanKurdRepository(), category: 'Ziman'),
          dark: dark,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('level-locked-more-3')));
      await tester.pumpAndSettle();

      final card = find.byKey(const ValueKey('level-card-2'));
      expect(
        find.descendant(of: card, matching: find.byType(Opacity)),
        findsNothing,
      );
      final hint = tester.widget<Text>(
        find.byKey(const ValueKey('level-lock-hint-2')),
      );
      expect(hint.style?.color, t.disabledFg);
      final title = tester.widget<Text>(
        find.descendant(of: card, matching: find.text('Temel')),
      );
      expect(title.style?.color, t.disabledFg);
    });

    testWidgets('pasif liste satırı: başlık belirteç rengi ($name)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          Scaffold(
            body: SahneListRow.plain(
              title: 'Silavkirin',
              enabled: false,
              onTap: null,
              trailing: const Icon(Icons.lock),
            ),
          ),
          dark: dark,
        ),
      );
      final title = tester.widget<Text>(find.text('Silavkirin'));
      expect(title.style?.color, t.disabledFg);
      expect(find.byType(Opacity), findsNothing);
    });
  }

  testWidgets('"Asta xwe bibîne" gövde metni karta 16 pt\'den yakın değil', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _app(LearningScreen(repository: MockZanKurdRepository()), lang: 'ku'),
    );
    await tester.pumpAndSettle();
    final card = tester.getRect(
      find.byKey(const ValueKey('learning-placement-prompt')),
    );
    // Tur 11: açıklama kalktı; şeritte kenara değebilecek metin başlık ve
    // "Dest bi azmûnê bike" eylemidir (sağda 48'lik kapatma düğmesi durur).
    final body = tester.getRect(
      find.descendant(
        of: find.byKey(const ValueKey('learning-placement-start')),
        matching: find.byType(Text),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(card.right - body.right, greaterThanOrEqualTo(16));
  });
}
