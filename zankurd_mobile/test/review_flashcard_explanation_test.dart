// Hafıza kartı açıklama bekçisi.
//
// Kusur: tekrar ekranının hafıza kartı arka yüzü, liste görünümünün
// kullandığı çözümleyiciyi atlayıp ham `AnswerRecord.explanation`ı
// basıyordu. Kurmancî seçiliyken `offline_0016` kartının arkasında ham
// Türkçe 'Doğru anlam: "pirtûk": "kitap".' görünüyordu; oysa aynı kayıt
// için Kurmancî açıklama override'ı vardı.
// Sessizdi çünkü liste görünümü doğru çözümlüyordu; yalnız kart bozuktu.
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/l10n/explanation_overrides.dart';
import 'package:zankurd_mobile/src/models/answer_record.dart';
import 'package:zankurd_mobile/src/screens/review_screen.dart';

void main() {
  test('hafıza kartı ham Türkçe açıklamayı Kurmancî turda göstermez', () {
    const record = AnswerRecord(
      id: 'offline_0016',
      category: 'Ziman',
      prompt: 'p',
      answers: ['a', 'b'],
      correctAnswer: 'a',
      selectedAnswer: 'b',
      explanation: 'Doğru anlam: "pirtûk": "kitap".',
    );
    final ku = resolveAnswerExplanation(record, true);
    final tr = resolveAnswerExplanation(record, false);
    expect(ku, explanationOverrides['offline_0016']!.ku);
    expect(ku, isNot(contains('Doğru anlam')));
    expect(tr, explanationOverrides['offline_0016']!.tr);
  });

  test('yazılmış açıklama override\'dan önce gelir', () {
    const record = AnswerRecord(
      id: 'offline_0016',
      category: 'Ziman',
      prompt: 'p',
      answers: ['a'],
      correctAnswer: 'a',
      selectedAnswer: 'a',
      explanation: 'ham',
      explanationKu: 'Şirove ya nivîskî ya Kurmancî.',
    );
    expect(
      resolveAnswerExplanation(record, true),
      'Şirove ya nivîskî ya Kurmancî.',
    );
  });
}
