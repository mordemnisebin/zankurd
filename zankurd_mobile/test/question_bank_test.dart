import 'package:flutter_test/flutter_test.dart';
import 'dart:io';

import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/data/offline_question_bank.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';

String _normalized(String value) =>
    value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

void main() {
  const validCategories = {
    'Ziman',
    'Çand',
    'Dîrok',
    'Edebiyat',
    'Cografya',
    'Muzîk',
    'Siyaset',
    'Paradigma',
    'Teknolojî',
  };

  test('all question ids are unique', () {
    final ids = offlineQuestionBank.map((q) => q.id).toList();
    expect(ids.toSet().length, ids.length);
  });

  test('every correct answer exists among its options', () {
    for (final question in offlineQuestionBank) {
      expect(
        question.answers,
        contains(question.correctAnswer),
        reason: '${question.id}: correctAnswer not in answers',
      );
    }
  });

  test('prompts do not leak the correct answer text', () {
    final offenders = <String>[];
    for (final question in offlineQuestionBank) {
      final correct = _normalized(question.correctAnswer);
      if (correct.length < 6) continue;

      final prompt = _normalized(question.prompt);
      if (prompt.contains(correct)) {
        offenders.add('${question.id}: ${question.correctAnswer}');
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'Soru metni cevabı açıkça göstermemeli: $offenders',
    );
  });

  test('every question uses a known category', () {
    for (final question in offlineQuestionBank) {
      expect(
        validCategories,
        contains(question.category),
        reason: '${question.id}: unknown category ${question.category}',
      );
    }
  });

  test('difficulties stay within 1-5', () {
    for (final question in offlineQuestionBank) {
      expect(
        question.difficulty,
        inInclusiveRange(1, 5),
        reason: '${question.id}: difficulty ${question.difficulty}',
      );
    }
  });

  test('answer options are unique per question', () {
    for (final question in offlineQuestionBank) {
      expect(
        question.answers.toSet().length,
        question.answers.length,
        reason: '${question.id}: duplicate options',
      );
    }
  });

  test('true/false questions use Rast/Şaş options', () {
    for (final question in offlineQuestionBank.where(
      (q) => q.type == QuestionType.trueFalse,
    )) {
      expect(question.answers, [
        'Rast',
        'Şaş',
      ], reason: '${question.id}: unexpected true/false options');
    }
  });

  test('bank grew past 1100 questions', () {
    expect(offlineQuestionBank.length, greaterThan(1100));
  });

  test('prompts carry no difficulty-tier prefix labels', () {
    const prefixes = ['Temel:', 'Pekiştirme:', 'Ustalık:'];
    final offenders = <String>[];
    for (final question in offlineQuestionBank) {
      final p = question.prompt.trimLeft();
      for (final prefix in prefixes) {
        if (p.startsWith(prefix)) {
          offenders.add('${question.id}: $p');
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason: 'Oyuncuya gösterilen prompt teknik önek taşımamalı: $offenders',
    );
  });

  // Bir seviyenin zorluk bandı içinde aynı prompt'un birden çok zorluk
  // kopyası tek quizde tekrar olarak çıkmasın diye seçim prompt'a göre
  // tekilleştiriyor (SeenQuestionStore.preferUnseen). Her bandın
  // prompt-bazında yeterli benzersiz sorusu olmalı.
  // Tam 5 seviyelik merdiven (Destpêk..Mamoste) yalnızca, en kolay seviyeyi
  // (zorluk 1, 10 soru) de doldurabilen "olgun" kategoriler için zorunludur.
  // Paradigma/Siyaset gibi ileri-kavramsal kategoriler bilinçli olarak
  // çoğunlukla orta-zor sorulardan oluşur (kullanıcının "az kolay soru"
  // tercihi); bunlara 10 yapay-kolay soru eklemek yerine tam-merdiven
  // testinden muaf tutulurlar. (Bu kategorilerin kolay seviyesi gerektiğinde
  // soruları döndürerek doldurur; preferUnseen tekrarları azaltır.)
  const ladderMaturityThreshold = 59; // 10+10+12+12+15
  bool isMature(String category) {
    final pool = offlineQuestionBank.where((q) => q.category == category);
    final easy = pool.where((q) => q.difficulty <= 1).length;
    return pool.length >= ladderMaturityThreshold && easy >= 10;
  }

  test('each level band has enough prompt-distinct questions', () {
    final repository = MockZanKurdRepository();
    for (final category in repository.categories) {
      if (!isMature(category)) continue;
      for (final level in repository.levelsForCategory(category)) {
        final distinctPrompts = offlineQuestionBank
            .where(
              (q) =>
                  q.category == category &&
                  q.difficulty >= level.difficultyMin &&
                  q.difficulty <= level.difficultyMax,
            )
            .map((q) => q.prompt.trim())
            .toSet()
            .length;
        expect(
          distinctPrompts,
          greaterThanOrEqualTo(level.questionCount),
          reason:
              '$category / ${level.title}: ${level.questionCount} benzersiz '
              'prompt gerekiyor, $distinctPrompts var',
        );
      }
    }
  });

  test('local question image references point to bundled assets', () {
    final missing = <String>[];
    for (final question in offlineQuestionBank.where((q) => q.hasImage)) {
      final imageUrl = question.imageUrl!;
      if (!imageUrl.startsWith('asset://')) continue;
      final path = imageUrl.replaceFirst('asset://', '');
      if (!File(path).existsSync()) {
        missing.add('${question.id}: $path');
      }
    }

    expect(missing, isEmpty);
  });

  // Her kategori, tanımlı 5 seviyenin her birini farklı sorularla
  // doldurabilmeli; aksi halde seviye quizi sessizce soruları tekrar eder.
  test(
    'every category can fill all its quiz levels with distinct questions',
    () {
      final repository = MockZanKurdRepository();
      for (final category in repository.categories) {
        if (!isMature(category)) continue;
        for (final level in repository.levelsForCategory(category)) {
          final pool = offlineQuestionBank
              .where(
                (q) =>
                    q.category == category &&
                    q.difficulty >= level.difficultyMin &&
                    q.difficulty <= level.difficultyMax,
              )
              .length;
          expect(
            pool,
            greaterThanOrEqualTo(level.questionCount),
            reason:
                '$category / ${level.title}: needs ${level.questionCount} '
                'distinct questions at difficulty '
                '${level.difficultyMin}-${level.difficultyMax}, has $pool',
          );
        }
      }
    },
  );
}
