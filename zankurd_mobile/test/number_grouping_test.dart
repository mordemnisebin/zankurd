/// Büyük sayaçlar binlik ayraçla yazılır ("1.119", "12.400").
///
/// ## Kusur
///
/// Mağaza ekran görüntüsü turunda Sözlük başlığı "1119 kelime ve ifade"
/// diye çıktı. Sayaçlar `'$n'` ile satır içinde yazılıyordu ve uygulamada
/// ortak bir sayı biçimleyici yoktu; sözlük, kategori kartı soru sayısı,
/// XP "340/1000", sıralama puanı, jeton bakiyesi ve tur puanı hep ham
/// yazıyordu.
///
/// ## Niçin sessiz kaldı
///
/// Geliştirme verisi küçüktür: sözlük testleri, kategoriler ve puanlar 999'u
/// geçmeyen örneklerle koşar, ham ve biçimli yazım orada AYNIDIR. Hata ancak
/// gerçek bankada (binden fazla kayıt) görünür; hiçbir test "dört
/// basamaklı değer nasıl yazılır" diye sormuyordu.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/learner_lexicon.dart';
import 'package:zankurd_mobile/src/screens/learner_lexicon_screen.dart';
import 'package:zankurd_mobile/src/utils/number_format.dart';

import 'support/widget_test_helpers.dart';

void main() {
  test('groupThousands: nokta ayracı, kısa sayılar ve eksi değerler', () {
    expect(groupThousands(0), '0');
    expect(groupThousands(7), '7');
    expect(groupThousands(999), '999');
    expect(groupThousands(1000), '1.000');
    expect(groupThousands(1119), '1.119');
    expect(groupThousands(12400), '12.400');
    expect(groupThousands(1234567), '1.234.567');
    expect(groupThousands(-1000), '-1.000');
    expect(groupThousands(-999), '-999');
  });

  testWidgets('Sözlük başlığı sayıyı binlik ayraçla yazar', (tester) async {
    await tester.pumpWidget(testShell(child: const LearnerLexiconScreen()));
    await tester.pump();
    final total = LearnerLexicon.search('').length;
    final text = tester
        .widget<Text>(find.byKey(const ValueKey('lexicon-result-count')))
        .data!;
    expect(
      text,
      '${groupThousands(total)} kelime ve ifade',
      reason: 'Sayaç ham yazıldı.',
    );
    expect(
      RegExp(r'^\d{1,3}(\.\d{3})* kelime ve ifade$').hasMatch(text),
      isTrue,
      reason: '"$text" binlik ayraç biçimine uymuyor.',
    );
    // Gerçek sözlük binden büyüktür; ayraç gerçekten devreye girmeli.
    expect(total, greaterThanOrEqualTo(1000));
    expect(text, contains('.'));
  });
}
