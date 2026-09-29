/// Şahnê liste satırının bekçisi (standart, bilgi, sıra, Sen).
///
/// ## Neyi korur
///
/// * Yükseklik EN AZ değerdir (64 / 52 / 56 / 64), sabit değil: Kurmancî
///   dizeler Türkçeden ~%30 uzundur ve eski satırlar sabit yükseklikle
///   ikinci satırı kesiyordu. Test uzun Kurmancî başlığın satırı
///   uzattığını ölçer.
/// * 320 px @2.0'da taşma yok: sağdaki rozet büyük yazıda metnin altına
///   iner, başlık harf harf bölünmez.
/// * Ekran okuyucu başlık + alt satırı (ve sağdaki rozetin sözünü) okur.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/theme/app_icons.dart';
import 'package:zankurd_mobile/src/widgets/sahne/sahne.dart';

import '../support/realistic_device.dart';
import 'sahne_harness.dart';

const _thumb = AssetImage('assets/question_images/cat_cand.webp');

void main() {
  setUpAll(loadAppFonts);

  Widget rows() => const Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SahneListGroup(
        children: [
          SahneListRow.icon(
            key: Key('standard'),
            icon: AppIcons.calendarDays,
            role: SahneRole.race,
            title: 'Çalakiya Rojê',
            subtitle: '10 pirs • 20 çirke/pirs',
            trailing: SahneBadge(label: 'Îro', tone: SahneBadgeTone.race),
            chevron: true,
            onTap: noop,
          ),
          SahneListRow.icon(
            icon: AppIcons.shuffle,
            title: 'Sırayla düello',
            subtitle: 'Sırası gelen oynar',
            enabled: false,
            trailing: SahneBadge(label: 'Yakında', tone: SahneBadgeTone.soon),
          ),
          SahneListRow.thumb(
            key: Key('info'),
            image: _thumb,
            title: 'Li Çayxanê',
            trailing: SahneRowValue.meta('4 deq'),
            chevron: true,
            onTap: noop,
          ),
          SahneListRow.rank(
            key: Key('rank'),
            rank: 4,
            initial: 'A',
            title: 'Azad',
            trailing: SahneRowValue('5980'),
          ),
        ],
      ),
      SizedBox(height: 12),
      SahneListRow.me(
        key: Key('me'),
        rank: 14,
        title: 'Tu',
        subtitle: 'Ji bo 10ên pêşîn 1.640 xal',
        trailing: SahneRowValue('2310'),
      ),
    ],
  );

  for (final MapEntry(key: name, value: dark) in kThemes.entries) {
    testWidgets('$name: 320 px @2.0 taşmaz, etiketler okunur', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpSahne(tester, rows(), dark: dark);
      expect(tester.takeException(), isNull);
      expect(
        find.bySemanticsLabel(RegExp(r'^Çalakiya Rojê, 10 pirs[\s\S]*Îro')),
        findsOneWidget,
      );
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      semantics.dispose();
    });
  }

  testWidgets('en az yükseklikler: 64 / 52 / 56 / 64', (tester) async {
    await pumpSahne(
      tester,
      rows(),
      dark: true,
      textScale: 1,
      size: const Size(390, 844),
    );
    double h(String k) => tester.getSize(find.byKey(Key(k))).height;
    expect(h('standard'), greaterThanOrEqualTo(64));
    expect(h('info'), greaterThanOrEqualTo(52));
    expect(h('info'), lessThan(64));
    expect(h('rank'), greaterThanOrEqualTo(56));
    expect(h('me'), greaterThanOrEqualTo(64));
  });

  testWidgets('uzun Kurmancî başlık satırı uzatır, kesilmez', (tester) async {
    await pumpSahne(
      tester,
      const Column(
        children: [
          SahneListRow.icon(
            key: Key('short'),
            icon: AppIcons.book,
            title: 'Ders',
          ),
          SahneListRow.icon(
            key: Key('long'),
            icon: AppIcons.book,
            title:
                'Hevokên rojane yên ku di jiyana rojane de herî zêde tên '
                'bikaranîn',
            subtitle: 'Bi dengê axaftvanekî xwecihî',
          ),
        ],
      ),
      dark: false,
      textScale: 1,
    );
    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.byKey(const Key('long'))).height,
      greaterThan(tester.getSize(find.byKey(const Key('short'))).height),
    );
    final long = tester.widget<Text>(find.textContaining('Hevokên rojane'));
    expect(long.maxLines, isNull);
    expect(long.overflow, isNot(TextOverflow.ellipsis));
  });

  testWidgets('Sen satırı altın Halka 1 taşır', (tester) async {
    await pumpSahne(
      tester,
      const SahneListRow.me(rank: 14, title: 'Sen'),
      dark: true,
      textScale: 1,
    );
    final material = tester.widget<Material>(
      find
          .descendant(
            of: find.byType(SahneListRow),
            matching: find.byType(Material),
          )
          .first,
    );
    final shape = material.shape! as BeveledRectangleBorder;
    expect(shape.side.color, SahneTokens.night.gold);
    expect(shape.side.width, SahneRing.r1);
  });
}
