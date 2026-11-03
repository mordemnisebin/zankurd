import '../data/learner_lexicon.dart';
import '../models/answer_record.dart';

/// Turun paylaşım kartına girecek "öğrendiğim sözcükler".
///
/// ## Niçin var
///
/// Paylaşım kartı yalnız skoru gösteriyordu; Wordle/Duolingo kartlarının
/// çekiciliği "bu turdan ne kaldı"yı da göstermesidir. Yeni çeviri ÜRETMEZ:
/// yalnız turdaki sorulardan, uygulamanın kendi sözlüğünde
/// ([LearnerLexicon]) bulunan Kurmancî sözcükleri seçer.
///
/// Sıra: önce YANLIŞ cevaplanan soruların sözcükleri (asıl öğrenilen onlar),
/// sonra doğrular; her soruda önce doğru cevabın sözcükleri, sonra sorudaki
/// ilk tırnaklı terim. Aynı madde bir kez, en çok [max] madde.
List<LearnerLexiconEntry> learnedWordsForRound(
  List<AnswerRecord> records, {
  int max = 3,
}) {
  final wrongFirst = [
    ...records.where((r) => !r.isCorrect && !r.isUnanswered),
    ...records.where((r) => r.isCorrect),
  ];
  final seen = <String>{};
  final out = <LearnerLexiconEntry>[];
  final word = RegExp(r'[\p{L}̧̂]+', unicode: true);

  void scan(String text) {
    for (final m in word.allMatches(text)) {
      if (out.length >= max) return;
      final token = m.group(0)!;
      if (token.runes.length < 3) continue;
      final entry = LearnerLexicon.lookup(token);
      if (entry != null && seen.add(entry.id)) out.add(entry);
    }
  }

  for (final r in wrongFirst) {
    if (out.length >= max) break;
    scan(r.correctAnswer);
    final quoted = RegExp('["“«]([^"”»]*)["”»]').firstMatch(r.prompt)?.group(1);
    if (quoted != null) scan(quoted);
  }
  return out;
}
