import 'dart:convert';
import 'dart:io';

import 'package:zankurd_mobile/src/data/curated_question_bank.dart';
import 'package:zankurd_mobile/src/data/question_bank_assets.dart';
import 'package:zankurd_mobile/src/data/question_bank_loader.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';

/// Test ortamında soru bankalarını JSON asset dosyalarından senkron yükler.
///
/// Testler `offlineQuestionBank` Dart const'ı yerine bu fonksiyonları kullanır.
/// Böylece 1.3 MB'lık Dart dosyası kod segmentinden çıkarılabilir.
///
/// dart:io File kullanımı test ortamında (flutter test) güvenlidir.
List<QuizQuestion> loadOfflineBankFromJson() {
  ensureQuestionBankLoaderInitialized();
  final raw = File('assets/data/offline_questions.json').readAsStringSync();
  final list = json.decode(raw) as List<dynamic>;
  return list
      .map((e) => QuizQuestion.fromJson(e as Map<String, dynamic>))
      .toList(growable: false);
}

/// `questionBankAssets` içindeki BÜTÜN bankaları yükler.
///
/// Tek banka yükleyicileri bir kuralı yalnız bir dosyada uygular ve
/// kuralın kapsamı sessizce dar kalır: çeldirici tür kuralı 2026-07-24'ten
/// beri yalnız `offline_questions.json`a bakıyordu, oysa o tarihten sonra
/// bankaya dokuz dosya daha eklendi (2026-08-24, A12).
List<QuizQuestion> loadEveryBankFromJson() {
  ensureQuestionBankLoaderInitialized();
  final all = <QuizQuestion>[];
  for (final asset in questionBankAssets) {
    final file = File(asset);
    if (!file.existsSync()) continue;
    final list = json.decode(file.readAsStringSync()) as List<dynamic>;
    all.addAll(
      list.map((e) => QuizQuestion.fromJson(e as Map<String, dynamic>)),
    );
  }
  return List.unmodifiable(all);
}

List<QuizQuestion> loadEditorialBankFromJson() {
  ensureQuestionBankLoaderInitialized();
  final raw = File('assets/data/editorial_questions.json').readAsStringSync();
  final list = json.decode(raw) as List<dynamic>;
  return list
      .map((e) => QuizQuestion.fromJson(e as Map<String, dynamic>))
      .toList(growable: false);
}

void ensureQuestionBankLoaderInitialized() {
  if (QuestionBankLoader.instance.isLoaded) return;
  final offlineRaw = File(
    'assets/data/offline_questions.json',
  ).readAsStringSync();
  final editorialRaw = File(
    'assets/data/editorial_questions.json',
  ).readAsStringSync();
  final offlineList = json.decode(offlineRaw) as List<dynamic>;
  final editorialList = json.decode(editorialRaw) as List<dynamic>;

  final offline = offlineList.map(
    (e) => QuizQuestion.fromJson(e as Map<String, dynamic>),
  );
  final editorial = editorialList.map(
    (e) => QuizQuestion.fromJson(e as Map<String, dynamic>),
  );

  QuestionBankLoader.instance.setQuestionsForTest([
    ...curatedQuestionBank,
    ...editorial,
    ...offline,
  ]);
}
