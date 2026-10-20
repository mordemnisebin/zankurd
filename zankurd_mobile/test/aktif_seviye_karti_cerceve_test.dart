// 2026-10-20 TASARIM KURULU (tur 6b): aktif seviye kartı iki temada aynı
// çerçeve diliyle.
//
// ## Kusur
//
// Seviye listesinde sıradaki seviye kartı AÇIK temada da koyu (#1E2228) bir
// gece adası olarak çiziliyordu; ekranın geri kalanı beyaz kartlardı ve ada
// uygulamanın açık kart diliyle çatışıyordu (2 denetçi).
//
// ## Niçin sessiz kalırdı
//
// Eski testler kartın "sahne kartı" olduğunu SABİTLİYORDU (kusuru koruyan
// bekçi); renk ya da çerçeve ölçen yoktu. Sözleşme: açık temada açık yüzey
// kartı, koyuda sahne kartı; ikisinde de 2 px Agir (turuncu) çerçeve; Başla
// düğmesi aynen.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/level_progress_store.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/screens/level_screen.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';
import 'package:zankurd_mobile/src/widgets/sahne/sahne.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    LevelProgressStore.resetInstance();
  });

  for (final dark in [false, true]) {
    testWidgets('aktif kart: ${dark ? 'koyu' : 'açık'} tema, 2 px Agir çerçeve', (
      tester,
    ) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(
              create: (_) => LanguageProvider()..setLang('tr'),
            ),
          ],
          child: MaterialApp(
            theme: dark ? AppTheme.dark() : AppTheme.light(),
            home: LevelScreen(
              repository: MockZanKurdRepository(),
              category: 'Ziman',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final t = dark ? SahneTokens.night : SahneTokens.day;
      final card = find.byKey(const ValueKey('level-card-1'));

      expect(
        find.descendant(of: card, matching: find.byType(SahneSurfaceCard)),
        dark ? findsNothing : findsOneWidget,
        reason: 'açık temada koyu ada yok',
      );
      expect(
        find.descendant(of: card, matching: find.byType(SahneStageCard)),
        dark ? findsOneWidget : findsNothing,
      );

      final frame = find
          .descendant(
            of: card,
            matching: find.byWidgetPredicate(
              (w) =>
                  w is DecoratedBox &&
                  w.position == DecorationPosition.foreground,
            ),
          )
          .first;
      final shape =
          ((tester.widget(frame) as DecoratedBox).decoration as ShapeDecoration)
                  .shape
              as OutlinedBorder;
      expect(shape.side.width, 2);
      expect(shape.side.color, t.act);
      expect(
        find.descendant(of: card, matching: find.byType(FilledButton)),
        findsOneWidget,
      );
    });
  }
}
