import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/achievement_store.dart';
import 'package:zankurd_mobile/src/data/level_progress_store.dart';
import 'package:zankurd_mobile/src/data/mastery_store.dart';
import 'package:zankurd_mobile/src/l10n/strings.dart';
import 'package:zankurd_mobile/src/providers/bilingual_labels_provider.dart';
import 'package:zankurd_mobile/src/screens/app_shell.dart';

import 'support/widget_test_helpers.dart';

/// Kurmancî alt sekme etiketi ("Rûpela sereke") ekran kenarına değiyordu.
///
/// ## Kusur
///
/// 2026-10-29 iPhone 17 Pro turu: Kurmancîde ilk sekmenin etiketi sekme
/// genişliğini (~100 pt) neredeyse tam dolduruyor, metin sol kenardan ~7 px
/// içeride başlıyordu; kenara yapışık görünüyordu.
///
/// ## Niçin sessiz kalabilirdi
///
/// Etiket kırpılmıyor ve taşmıyordu; yalnız kenar boşluğu yoktu. Hiçbir
/// "taşma" bekçisi bunu görmez.
///
/// ## Bekçi
///
/// 320-430 genişlikte, 1.0 ve 1.3 yazı ölçeğinde, her sekme etiketinin
/// ekran kenarına en az 8 pt boşluğu vardır ve çubukta taşma çıkmaz.
void main() {
  setUp(() {
    AchievementStore.resetInstance();
    SharedPreferences.setMockInitialValues({});
    MasteryStore.resetInstance();
    LevelProgressStore.resetInstance();
  });

  for (final width in [320.0, 360.0, 375.0, 402.0, 430.0]) {
    for (final scale in [1.0, 1.3]) {
      testWidgets('KU sekme etiketleri kenara değmez ($width, x$scale)', (
        tester,
      ) async {
        tester.view.devicePixelRatio = 3;
        tester.view.physicalSize = Size(width * 3, 780 * 3);
        tester.view.padding = const FakeViewPadding(
          top: 50 * 3,
          bottom: 34 * 3,
        );
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider(
                create: (_) => BilingualLabelsProvider(initialEnabled: false),
              ),
            ],
            child: testShell(
              languageProvider: kurmanciLang(),
              child: Builder(
                builder: (context) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(scale)),
                  child: AppShell(repository: freshMockRepository()),
                ),
              ),
            ),
          ),
        );
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 120));
        }
        expect(tester.takeException(), isNull);
        final bar = find.byType(NavigationBar);
        expect(bar, findsOneWidget);
        final slot = width / 4;
        final labels = [K.navLearn, K.navPlay, K.navLeaderboard, K.navProfile];
        for (var i = 0; i < 4; i++) {
          final label = Tr.forKu(labels[i], true);
          final finder = find.descendant(
            of: bar,
            matching: find.text(label, findRichText: true),
          );
          expect(finder, findsAtLeastNWidgets(1), reason: label);
          final para = tester.renderObject<RenderParagraph>(finder.first);
          // Yazının GERÇEK mürekkep sınırı (Text kutusu sekme genişliğinde
          // gerilir; kutuya bakmak kenara yapışmayı göstermez).
          final boxes = para.getBoxesForSelection(
            TextSelection(baseOffset: 0, extentOffset: label.length),
          );
          expect(boxes.length, 1, reason: '"$label" iki satıra kırıldı');
          final origin = para.localToGlobal(Offset.zero);
          debugPrint(
            'DBG $width $label size=${para.size} origin=$origin boxes=$boxes',
          );
          final left =
              origin.dx +
              boxes.map((b) => b.left).reduce((a, b) => a < b ? a : b);
          final right =
              origin.dx +
              boxes.map((b) => b.right).reduce((a, b) => a > b ? a : b);
          expect(
            left,
            greaterThanOrEqualTo(8),
            reason: '"$label" sol kenara çok yakın: $left',
          );
          expect(
            right,
            lessThanOrEqualTo(width - 8),
            reason: '"$label" sağ kenara çok yakın: $right',
          );
          // Etiket kendi sekmesinin içinde kalır (komşuya taşmaz).
          expect(left, greaterThanOrEqualTo(i * slot));
          expect(right, lessThanOrEqualTo((i + 1) * slot));
        }
      });
    }
  }
}
