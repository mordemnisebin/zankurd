import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/config/category_visuals.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/services/question_set_policy.dart';

/// Topluluk katkısı soru setinin bütünlüğü.
///
/// Bu sorular elle yazıldı (doğru cevap kaynakta '•' ile işaretliydi), yani
/// üretilmiş bankadan farklı hatalara açıklar: işaretlenmemiş cevap, şıklar
/// arasında bulunmayan doğru cevap, tanımsız kategori. Test bunları
/// yakalar — bir soru sessizce cevapsız kalırsa tur bozulur.
void main() {
  late List<QuizQuestion> questions;

  setUpAll(() {
    final file = File('assets/data/community_questions.json');
    expect(file.existsSync(), isTrue, reason: 'topluluk seti bulunamadı');
    questions = (jsonDecode(file.readAsStringSync()) as List)
        .cast<Map<String, dynamic>>()
        .map(QuizQuestion.fromJson)
        .toList();
  });

  test('set boş değil ve kimlikler benzersiz', () {
    expect(questions, isNotEmpty);
    final ids = questions.map((q) => q.id).toList();
    expect(ids.toSet().length, ids.length, reason: 'yinelenen id var');
  });

  test('her sorunun doğru cevabı şıkları arasında', () {
    // En sinsi hata biçimi: doğru cevap şıklarda yoksa hiçbir şık doğru
    // işaretlenmez ve kullanıcı ne yaparsa yapsın yanlış sayılır.
    for (final question in questions) {
      expect(
        question.answers,
        contains(question.correctAnswer),
        reason: '${question.id}: doğru cevap şıklar arasında değil',
      );
    }
  });

  test('şık sayısı ve benzersizliği tutarlı', () {
    for (final question in questions) {
      expect(
        question.answers.length,
        greaterThanOrEqualTo(2),
        reason: '${question.id}: en az iki şık gerekir',
      );
      expect(
        question.answers.toSet().length,
        question.answers.length,
        reason: '${question.id}: yinelenen şık var',
      );
      for (final option in question.answers) {
        expect(
          option.trim(),
          isNotEmpty,
          reason: '${question.id}: boş şık var',
        );
      }
    }
  });

  test('kategoriler tanımlı ve görsel kimliği var', () {
    final defined = CategoryVisuals.colorDefinedCategories.toSet();
    for (final question in questions) {
      expect(
        defined,
        contains(question.category),
        reason:
            '${question.id}: "${question.category}" kategorisinin rengi '
            'tanımlı değil; fallback renge düşer.',
      );
      // Kategori adı TR arayüzde çevrilmeli, ham Kurmancî kimlik değil.
      expect(CategoryNames.localized(question.category, false), isNotEmpty);
    }
  });

  test('çok dilli alanlar tutarlı — TR arayüzde tam gösterilebilir', () {
    // Şıklar özel ad/yıl olduğu için iki dilde aynı; bu yüzden setin
    // tamamı Türkçe gösterilebilir olmalı.
    for (final question in questions) {
      expect(
        question.hasTurkishTranslation,
        isTrue,
        reason: '${question.id}: Türkçe karşılık eksik ya da tutarsız',
      );
      final tr = question.localized(isKu: false);
      expect(
        tr.answers,
        contains(tr.correctAnswer),
        reason: '${question.id}: TR yansıtmasında doğru cevap şıklarda yok',
      );
    }
  });

  test('aynı kategoride cevap sızdıran çiftler süzgeçten geçiyor', () {
    // Set küçük ve elle yazıldığı için bazı sorular aynı isimleri paylaşır
    // (ör. Kobanê şehitleri). Bu bir hata değil; süzgecin bunları aynı tura
    // koymadığını doğrulamak yeterli.
    final byCategory = <String, List<QuizQuestion>>{};
    for (final question in questions) {
      byCategory.putIfAbsent(question.category, () => []).add(question);
    }
    for (final entry in byCategory.entries) {
      final clean = QuestionSetPolicy.withoutLeaks(entry.value);
      for (var i = 0; i < clean.length; i++) {
        for (var j = i + 1; j < clean.length; j++) {
          expect(
            QuestionSetPolicy.leaksBetween(clean[i], clean[j]),
            isFalse,
            reason:
                '${entry.key}: ${clean[i].id} ile ${clean[j].id} '
                'süzgeçten sonra hâlâ sızdırıyor',
          );
        }
      }
    }
  });
}
