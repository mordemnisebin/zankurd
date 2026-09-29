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

  // 2026-09-29 doğallık (K7): ayarlar ve eşleşme listelerinde ikon karosu
  // metni tekrarlıyordu (her satırın başında aynı boy kare: şablon izi).
  // İkonsuz satır öncül için boşluk bırakmaz; metin kenardan (16) başlar,
  // satırın tamamı dokunulur, ayırıcı da metnin hizasından başlar.
  testWidgets('ikonsuz satır: boşluksuz başlar, tamamı dokunulur', (
    tester,
  ) async {
    var taps = 0;
    await pumpSahne(
      tester,
      SahneListGroup(
        children: [
          SahneListRow.plain(
            key: const Key('a'),
            title: 'Ziman',
            trailing: const SahneRowValue.meta('Kurmancî'),
            onTap: () => taps++,
          ),
          SahneListRow.plain(
            key: const Key('b'),
            title: 'Agahdarî',
            chevron: true,
            onTap: () => taps++,
          ),
        ],
      ),
      dark: false,
      textScale: 1,
    );
    expect(tester.takeException(), isNull);
    final row = tester.getRect(find.byKey(const Key('a')));
    final title = tester.getRect(find.text('Ziman'));
    expect(title.left - row.left, SahneSpace.x4);
    expect(tester.getSize(find.byKey(const Key('a'))).height, 56);
    expect(
      (tester.widget(find.byKey(const Key('b'))) as SahneListRow).dividerIndent,
      SahneSpace.x4,
    );
    // Satırın sağ ucuna (değerin dışına) dokunmak da sayılır.
    await tester.tapAt(Offset(row.left + row.width * 0.6, row.center.dy));
    await tester.tapAt(tester.getCenter(find.byKey(const Key('b'))));
    expect(taps, 2);
  });

  testWidgets('sıra avatarı pahlı kare (K5), eski ad hâlâ derlenir', (
    tester,
  ) async {
    await pumpSahne(
      tester,
      const SahneDiamondAvatar(initial: 'R'),
      dark: true,
      textScale: 1,
    );
    final box = tester.widget<DecoratedBox>(
      find.descendant(
        of: find.byType(SahneAvatar),
        matching: find.byType(DecoratedBox),
      ),
    );
    final shape =
        (box.decoration as ShapeDecoration).shape as BeveledRectangleBorder;
    expect(shape.borderRadius, SahneShape.m.borderRadius);
  });
}
