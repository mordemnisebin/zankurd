import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/question_bank_loader.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/services/question_content_policy.dart';

/// Aynı olgu iki OYNANABİLİR kayıtla sorulmaz.
///
/// ## Kusur (Codex denetimi 2026-10-29, içerik #10)
///
/// `hat_0084` ve `hat_0094` ikisi de "Mitanni devletinin başkenti
/// hangisiydi?" diye soruyordu (aynı Türkçe soru, aynı cevap Waşûkanî, aynı
/// kaynak). Günlük seçim karıştırıp ilk kayıtları aldığından ikisi aynı
/// turda çıkabiliyor, ilki ikincisinin cevabını öğretiyordu.
///
/// ## Niçin sessiz kalırdı
///
/// `playable_prompt_uniqueness_test` yalnız BİREBİR aynı Kurmancî metni
/// yakalıyordu; bu iki kaydın Kurmancî metni farklı yazılmıştı
/// ("Mîtanniyê" / "Mîtanniyan ... bajar"). Türkçe soru + doğru cevap
/// anahtarına kimse bakmıyordu.
///
/// ## Kural
///
/// Oynanabilir (emekli olmayan) çoktan seçmeli sorularda aynı Türkçe soru
/// metni + aynı Türkçe doğru cevap yalnız bir kimlikte bulunur. Fazlalık
/// `retired_question_ids.dart`a eklenir. Günlük seçim de ([MockZanKurdRepository]
/// `_dedupeSameFact`) aynı anahtarı tekilleştirir.
void main() {
  test('oynanabilir sorularda aynı Türkçe soru + cevap tek kimlikte durur', () {
    const policy = QuestionContentPolicy();
    final byFact = <String, Set<String>>{};
    for (final q in QuestionBankLoader.instance.allQuestions) {
      if (q.type != QuestionType.multipleChoice || !policy.isPlayable(q)) {
        continue;
      }
      final prompt = q.promptTr?.trim().toLowerCase() ?? '';
      final answer = q.correctAnswerTr?.trim().toLowerCase() ?? '';
      if (prompt.isEmpty || answer.isEmpty) continue;
      byFact.putIfAbsent('$prompt | $answer', () => {}).add(q.id);
    }
    final duplicates = {
      for (final entry in byFact.entries)
        if (entry.value.length > 1) entry.key: entry.value.toList()..sort(),
    };
    expect(duplicates, isEmpty);
  });
}
