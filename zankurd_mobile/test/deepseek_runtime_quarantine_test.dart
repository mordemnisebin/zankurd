import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/question_bank_assets.dart';
import 'package:zankurd_mobile/src/data/question_bank_loader.dart';

/// DeepSeek bankası olgusal hata oranı yüzünden oyuncuya yüklenmez.
///
/// Dosya inceleme için durabilir; runtime listesine dönmesi bu bekçiyi
/// kırar.
void main() {
  const quarantined = 'assets/data/deepseek_2026_08_18_questions.json';

  test('DeepSeek bankası runtime listesinde yok', () {
    expect(questionBankAssets, isNot(contains(quarantined)));
  });

  test('yükleyici DeepSeek kayıtlarını oyuncuya vermez', () {
    final file = File(quarantined);
    expect(file.existsSync(), isTrue, reason: 'karantina dosyayı silmez');
    final ids = (jsonDecode(file.readAsStringSync()) as List)
        .cast<Map<String, dynamic>>()
        .map((row) => row['id'] as String)
        .toSet();
    expect(ids, isNotEmpty);

    final loadedIds = QuestionBankLoader.instance.allQuestions
        .map((q) => q.id)
        .toSet();
    expect(
      loadedIds.intersection(ids),
      isEmpty,
      reason: 'Karantinadaki kayıtlar hâlâ yükleniyor.',
    );
  });
}
