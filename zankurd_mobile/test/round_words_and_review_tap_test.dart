import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/data/learner_lexicon.dart';
import 'package:zankurd_mobile/src/models/answer_record.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';
import 'package:zankurd_mobile/src/utils/round_words.dart';
import 'package:zankurd_mobile/src/widgets/lexicon_lookup.dart';

/// Paylaşım kartının sözcükleri ve tur sonu "dokun-çevir" kuralı.
///
/// Kusur: kart yalnız skoru gösteriyordu; sözlükteki Kurmancî sözcükler tur
/// sonunda dokunulamıyordu. Bu bekçi iki şeyi korur: (1) kart sözcükleri
/// yalnız uygulama sözlüğünden gelir (uydurma çeviri yok), en çok 3, yanlış
/// cevaplananlar önce; (2) inceleme metni yalnız Kurmancî arayüzde (ya da
/// Kurmancî cevap isteyen soruda) dokunulabilir — Türkçe arayüzde Türkçe
/// "ev" sözlükteki Kurmancî "ev" ile karışmaz.
AnswerRecord _rec(String prompt, String correct, {required bool right}) =>
    AnswerRecord(
      id: prompt,
      category: 'Ziman',
      prompt: prompt,
      answers: [correct, 'x'],
      correctAnswer: correct,
      selectedAnswer: right ? correct : 'x',
      explanation: '',
    );

void main() {
  test('kart sözcükleri sözlükten gelir, en çok 3, tekrarsız', () {
    final entries = LearnerLexicon.search('a').take(6).toList();
    expect(entries.length, greaterThan(3));
    final records = [
      for (final e in entries) _rec('Soru', e.termKu, right: false),
    ];
    final words = learnedWordsForRound(records);
    expect(words.length, lessThanOrEqualTo(3));
    expect({for (final w in words) w.id}.length, words.length);
    for (final w in words) {
      expect(LearnerLexicon.byId(w.id), isNotNull);
    }
  });

  test('sözlükte olmayan metinden sözcük çıkmaz', () {
    expect(
      learnedWordsForRound([_rec('Soru', 'qqqzzz', right: true)]),
      isEmpty,
    );
  });

  test('inceleme politikası dile göre açılır', () {
    expect(LexiconTapPolicy.forReview(isKu: true, prompt: 'x').enabled, isTrue);
    expect(
      LexiconTapPolicy.forReview(isKu: false, prompt: 'x').enabled,
      isFalse,
    );
    expect(
      LexiconTapPolicy.forReview(
        isKu: false,
        prompt: '"Mal" bi Kurmancî çi ye?',
        isAnswer: true,
      ).enabled,
      isTrue,
    );
  });

  testWidgets('Kurmancî arayüzde açıklamadaki sözcüğe dokununca sayfa açılır', (
    tester,
  ) async {
    final entry = LearnerLexicon.lookup('Mal')!;
    await tester.pumpWidget(
      ChangeNotifierProvider<LanguageProvider>(
        create: (_) => LanguageProvider()..setLang('ku'),
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: LexiconText(
              entry.termKu,
              style: const TextStyle(fontSize: 14),
              policy: LexiconTapPolicy.forReview(isKu: true, prompt: 'x'),
            ),
          ),
        ),
      ),
    );
    expect(
      find.byKey(
        ValueKey('lexicon-word-${LearnerLexicon.foldForSearch(entry.termKu)}'),
      ),
      findsWidgets,
    );
  });
}
