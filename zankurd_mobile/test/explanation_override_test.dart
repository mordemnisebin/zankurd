import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/l10n/explanation_overrides.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';

QuizQuestion _q({
  required String id,
  String explanation = 'şablon açıklama',
  String? explanationKu,
  String? explanationTr,
}) => QuizQuestion(
  id: id,
  category: 'Dîrok',
  prompt: 'p',
  answers: const ['a', 'b'],
  correctAnswer: 'a',
  explanation: explanation,
  explanationKu: explanationKu,
  explanationTr: explanationTr,
);

void main() {
  test('override id için elle yazılmış açıklama döner (TR ve KU)', () {
    // offline_2087 override haritasında mevcut (Şerefname).
    final q = _q(id: 'offline_2087');
    expect(q.getLocalizedExplanation(false), contains('Şerefname'));
    expect(q.getLocalizedExplanation(true), contains('Şerefname'));
    // Şablona düşmemeli.
    expect(q.getLocalizedExplanation(false), isNot('şablon açıklama'));
  });

  test('soruya özel explanationTr override\'dan önceliklidir', () {
    final q = _q(id: 'offline_2087', explanationTr: 'DB açıklaması');
    expect(q.getLocalizedExplanation(false), 'DB açıklaması');
  });

  test('override yoksa şablona düşer', () {
    final q = _q(id: 'offline_nonexistent_999');
    expect(q.getLocalizedExplanation(false), 'şablon açıklama');
  });

  test('override haritası boş alan içermez', () {
    for (final entry in explanationOverrides.entries) {
      expect(entry.value.ku.trim(), isNotEmpty, reason: '${entry.key} ku boş');
      // tr opsiyoneldir (verilmezse şablona düşer); yalnız doluysa boş
      // olmamalı.
      expect(entry.value.tr.trim(), isNotEmpty, reason: '${entry.key} tr boş');
    }
  });

  test('en az 90 elle yazılmış açıklama mevcut', () {
    expect(explanationOverrides.length, greaterThanOrEqualTo(90));
  });

  test('Edebiyat/Muzîk partisi eklendi (helbest, tembûr)', () {
    expect(explanationOverrides['offline_0654']?.tr, contains('şiir'));
    expect(explanationOverrides['offline_0892']?.tr, contains('telli'));
  });

  test('Ziman temel kelime partisi eklendi (av, roj, heval)', () {
    expect(explanationOverrides['offline_0005']?.tr, contains('su'));
    expect(explanationOverrides['offline_0010']?.ku, contains('Roj'));
    expect(explanationOverrides['offline_0045']?.tr, contains('arkadaş'));
  });

  group('şablon açıklama guard\'ı', () {
    test('bilinen şablon desenleri yakalanır', () {
      const templates = [
        "Ev ravekirin têgeha 'azadî' nîşan dide.",
        "'govend' di vê kategoriyê de têgeheke girîng e.",
        "Têgeha 'çiya' di qada cografya de bi vê ravekirinê tê bikaranîn.",
        "Ev ravekirin bi 'stran' û qada muzîk re girêdayî ye.",
        "Görsel 'dar' kavramını gösterir; doğru yanıt: ağaç.",
        "'Ferat' için sorudaki iddia doğru değildir; doğru cevap 'Dîcle'dir.",
        'Doğru yanıt: doğru.',
        'Görsel soru "kew" kelimesini pekiştirir.',
        'tembûr Kürt müziği kategorisinde ele alınır.',
        'roman Kürt edebiyatı kategorisinde değerlendirilir.',
        'Pirsa wêneyî peyva "dar" xurt dike.',
        '',
        '   ',
      ];
      for (final t in templates) {
        expect(
          isTemplateExplanation(t),
          isTrue,
          reason: 'şablon sayılmalı: $t',
        );
      }
    });

    test('gerçek açıklamalar şablon sayılmaz', () {
      const real = [
        'Newroz, 21 Mart\'ta kutlanan ve baharın gelişini simgeleyen bir '
            'bayramdır.',
        'Dengbêj hunermendê çanda devkî ya kurdî ye ku bi awaz çîrokan '
            'vedibêje.',
        '"kevin" kelimesi "eski" demektir.',
      ];
      for (final t in real) {
        expect(isTemplateExplanation(t), isFalse, reason: 'gerçek: $t');
      }
    });

    test('getLocalizedExplanation şablonda boş döner', () {
      final q = _q(
        id: 'offline_nonexistent_999',
        explanation: "Ev ravekirin têgeha 'azadî' nîşan dide.",
      );
      expect(q.getLocalizedExplanation(false), isEmpty);
      expect(q.getLocalizedExplanation(true), isEmpty);
    });

    test('DB açıklaması şablonsa da elenir, override kazanır', () {
      final q = _q(
        id: 'offline_2087',
        explanationTr: 'Pirsa wêneyî peyva "dar" xurt dike.',
      );
      expect(q.getLocalizedExplanation(false), contains('Şerefname'));
    });

    test('resolveRawExplanation: override > şablon eleme > yerelleştirme', () {
      expect(
        resolveRawExplanation(
          id: 'offline_2087',
          explanation: "Ev ravekirin têgeha 'x' nîşan dide.",
          isKu: false,
        ),
        contains('Şerefname'),
      );
      expect(
        resolveRawExplanation(
          id: 'yok_boyle_id',
          explanation: "'stran' di vê kategoriyê de têgeheke girîng e.",
          isKu: true,
        ),
        isEmpty,
      );
      expect(
        resolveRawExplanation(
          id: 'yok_boyle_id',
          explanation: '"kevin" kelimesi "eski" demektir.',
          isKu: true,
        ),
        'Peyva "kevin" tê wateya "eski".',
      );
    });
  });
}
