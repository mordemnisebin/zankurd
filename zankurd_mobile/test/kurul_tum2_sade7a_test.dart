// Tasarım kurulu 2. tur 2026-10-20 (9 model, 35 ekran): ortak bulgular.
//
// 1. Üst satır her soru modunda aynı bileşendir (`QuizStageCenter`):
//    "Soru n/N · Kategori". Eskiden kimi modda ortada, kimi modda ayrı
//    satırda, düelloda hiç yoktu.
// 2. Jetonu yetmeyen joker kilit simgesi taşır; soluk dolgu tek başına
//    "etkin" okunmasını engellemiyordu (ekran 16, üç model).
// 3. Sonuç gövdesi kayıyorsa dibinde perde rengine solan bant vardır
//    (`SahneBottomFade`): alt perde kartı ortadan kesiyordu (68/69/200).
// 4. "Açıklamayı gör" çerçeveli, dolgusuz düğmedir; dolgulu yeşil çubuk
//    beşinci şık gibi okunuyordu (ekran 84).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/models/wildcard.dart';
import 'package:zankurd_mobile/src/screens/quiz/quiz_wildcard_bar.dart';
import 'package:zankurd_mobile/src/widgets/quiz_top_bar.dart';

import 'support/widget_test_helpers.dart';

Widget _host(Widget child) => testShell(
  child: Scaffold(body: Center(child: child)),
);

void main() {
  testWidgets('ortak üst satır kategori ve sırayı birlikte yazar', (t) async {
    await t.pumpWidget(
      _host(const QuizStageCenter(category: 'Ziman', index: 2, total: 7)),
    );
    final text = t.widget<Text>(
      find.byKey(const ValueKey('quiz-stage-kicker')),
    );
    expect(text.data, startsWith('Soru 3/7'));
    expect(text.data, contains('·'));
  });

  testWidgets('jetonu yetmeyen joker kilit gösterir, yetene kilit yok', (
    t,
  ) async {
    Widget joker({required bool cant}) => WildcardButton(
      type: WildcardType.fiftyFifty,
      isKu: false,
      isEnabled: !cant,
      isUsed: false,
      isAnswered: false,
      isActive: false,
      cantAfford: cant,
      onTap: () {},
      onLockedTap: () {},
    );
    await t.pumpWidget(_host(SizedBox(width: 120, child: joker(cant: true))));
    expect(find.byKey(const ValueKey('joker-locked-glyph')), findsOneWidget);
    await t.pumpWidget(_host(SizedBox(width: 120, child: joker(cant: false))));
    expect(find.byKey(const ValueKey('joker-locked-glyph')), findsNothing);
  });
}
