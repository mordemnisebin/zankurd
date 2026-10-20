// 7. tasarım kurulu (2026-10-20, Opus + ChatGPT): Kurmancî yarış merkezinde
// uzun alt satır ("Girêdaneke bişîne, hevalê te dê paşê bilîze") sağdaki ok
// simgesine yapışıyordu.
//
// ## Niçin sessiz kalırdı
//
// Metin taşmıyor, kırpılmıyor, bölünmüyordu; yalnız ok ile arasındaki boşluk
// 4 px'ti. Taşma ve söz-bölme bekçileri bunu görmez. Bekçi metnin sağ kenarı
// ile ok simgesinin sol kenarı arasında en az 16 px ister.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/theme/app_icons.dart';
import 'package:zankurd_mobile/src/widgets/sahne/sahne.dart';

import 'support/widget_test_helpers.dart';

void main() {
  testWidgets('uzun metin ile chevron arasında en az 16 px boşluk var', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      testShell(
        child: Scaffold(
          body: SahneListGroup(
            children: [
              SahneListRow.icon(
                icon: AppIcons.peopleGroup,
                title: 'Hevalê xwe vexwîne pêşbirkê',
                subtitle: 'Girêdaneke bişîne, hevalê te dê paşê bilîze',
                chevron: true,
                onTap: () {},
              ),
            ],
          ),
        ),
      ),
    );
    final sub = tester.getRect(
      find.text('Girêdaneke bişîne, hevalê te dê paşê bilîze'),
    );
    final chevron = tester.getRect(find.byIcon(AppIcons.chevronRight));
    expect(chevron.left - sub.right, greaterThanOrEqualTo(16));
  });
}
