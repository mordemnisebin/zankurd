import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/contest.dart';
import 'package:zankurd_mobile/src/screens/contest_screen.dart';
import 'package:zankurd_mobile/src/screens/friends_screen.dart';
import 'support/widget_test_helpers.dart';
import 'support/realistic_device.dart';

void main() {
  setUpAll(loadAppFonts);
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final size in [
    const Size(320, 568),
    const Size(375, 812),
    const Size(430, 932),
    const Size(420, 912),
    const Size(393, 852),
  ]) {
    for (final ku in [false, true]) {
      for (final scale in [1.0, 1.3]) {
        final label = '${size.width} ${ku ? 'KU' : 'TR'} ×$scale';
        Future<void> pump(WidgetTester tester, Widget child) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = size;
          addTearDown(tester.view.reset);
          await tester.pumpWidget(
            testShell(
              languageProvider: ku ? kurmanciLang() : turkishLang(),
              child: MediaQuery(
                data: MediaQueryData(
                  size: size,
                  padding: const EdgeInsets.only(top: 59, bottom: 34),
                  textScaler: TextScaler.linear(scale),
                ),
                child: child,
              ),
            ),
          );
          await tester.pumpAndSettle();
        }

        testWidgets('T11 arkadaş arama ipucu eksiksiz $label', (tester) async {
          await pump(
            tester,
            FriendsScreen(repository: MockZanKurdRepository()),
          );
          final field = find.byType(TextField).first;
          final hint = tester.widget<TextField>(field).decoration!.hintText!;
          final paragraph = tester.renderObject<RenderParagraph>(
            find.descendant(of: field, matching: find.text(hint)),
          );
          expect(
            paragraph.didExceedMaxLines,
            isFalse,
            reason: 'Arama ipucu kesilmemeli',
          );
          expect(tester.takeException(), isNull);
        });
        testWidgets(
          'T11 günlük katılımcı paragrafı ilk görünümde bölünmez $label',
          (tester) async {
            final repository = MockZanKurdRepository()
              ..sampleDailyEventBoard = const DailyEventBoard(
                participants: 1,
                top: [],
              );
            await pump(tester, ContestScreen(repository: repository));
            final line = tester.getRect(
              find.byKey(const ValueKey('daily-event-participants')),
            );
            final start = find.byKey(const ValueKey('contest-start'));
            final startRect = tester.getRect(start);
            expect(line.bottom, lessThan(startRect.top));
            expect(line.top, greaterThanOrEqualTo(59));
            expect(startRect.bottom, lessThanOrEqualTo(size.height - 34));
            expect(
              find
                  .byKey(const ValueKey('daily-event-participants'))
                  .hitTestable(),
              findsOneWidget,
            );
            expect(start.hitTestable(), findsOneWidget);
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }
}
