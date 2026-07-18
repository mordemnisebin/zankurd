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
}
