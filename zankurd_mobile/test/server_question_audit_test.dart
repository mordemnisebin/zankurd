import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/services/question_language_policy.dart';

/// Sunucudan dışa aktarılan soruları YEREL politikayla denetler.
///
/// ## Niçin var
///
/// Yerel bankalar (1787 soru) temiz ama oda maçları soruları sunucudan
/// alıyor ve sunucu bankası ayrışmış. Canlı bir maçta:
///
///   Di Kurmancî de peyva "kursî" bi Tirkî çi ye?
///     A) Öğrenmek  B) Öğretmen  C) Sandalye ✓  D) Dibistan
///
/// SQL'de harf temelli tarama bunu YAKALAYAMAZ: `Dibistan` Kurmancî'ye
/// özgü hiçbir harf taşımıyor. Gerçek sınıflandırma yerelde,
/// `QuestionLanguagePolicy` ile yapılmalı — üstelik bankalarla aynı
/// sınıflandırıcı olmalı ki iki denetim ayrışmasın.
///
/// ## Nasıl beslenir
///
///   1. `supabase/2026-08-01_question_export_for_audit.sql` çalıştırılır.
///   2. Sonuç **Export → Download CSV** ile indirilir.
///   3. Dosya `tool/server_questions_export.csv` adıyla konur.
///
/// Dosya yoksa test atlanır: bu bir bekçi değil, elde veri varken koşan
/// bir denetimdir. Sunucu bankası her değiştiğinde yeniden dökülüp
/// buradan geçirilebilir.
void main() {
  const path = 'tool/server_questions_export.csv';

  test('sunucu soruları dil politikasından geçiyor', () {
    final file = File(path);
    if (!file.existsSync()) {
      // ignore: avoid_print
      print(
        'ATLANDI: $path yok. Dışa aktarım için '
        'supabase/2026-08-01_question_export_for_audit.sql çalıştırılmalı.',
      );
      return;
    }

    final rows = _parseCsv(file.readAsStringSync());
    expect(
      rows,
      isNotEmpty,
      reason: 'CSV boş görünüyor; dışa aktarım eksik olabilir.',
    );
    const requiredColumns = {
      'id',
      'prompt',
      'option_a',
      'option_b',
      'option_c',
      'option_d',
      'correct_option',
      'correct_answer',
    };
    expect(
      rows.first.keys,
      containsAll(requiredColumns),
      reason:
          'CSV başlığı beklenen soru alanlarını içermiyor; SQL çıktısına '
          'SET/NOTICE gibi satırlar karışmış olabilir.',
    );
    expect(
      rows.where((row) => (row['id'] ?? '').trim().isNotEmpty).length,
      greaterThan(1000),
      reason: "CSV soru ID'leri içermiyor; dışa aktarım eksik olabilir.",
    );

    const policy = QuestionLanguagePolicy();
    final offLanguage = <String>[];
    final givenAway = <String>[];
    final inconsistent = <String>[];

    for (final row in rows) {
      final answers = [
        row['option_a'] ?? '',
        row['option_b'] ?? '',
        row['option_c'] ?? '',
        row['option_d'] ?? '',
      ].where((a) => a.trim().isNotEmpty).toList();
      if (answers.length < 2) continue;

      final question = QuizQuestion(
        id: row['id'] ?? '?',
        category: 'Ziman',
        prompt: row['prompt'] ?? '',
        answers: answers,
        correctAnswer: row['correct_answer'] ?? '',
        explanation: '',
      );

      final bad = policy.offLanguageDistractors(question);
      if (bad.isNotEmpty) {
        offLanguage.add(
          '${question.id} | ${question.prompt}\n'
          '    şıklar: ${answers.join(" · ")}\n'
          '    doğru: ${question.correctAnswer}\n'
          '    yabancı: ${bad.join(", ")}',
        );
      }
      if (policy.answerIsGivenAwayByLanguage(question)) {
        givenAway.add('${question.id} | ${question.prompt}');
      }
      if (!policy.isConsistent(question)) {
        inconsistent.add('${question.id} | ${question.prompt}');
      }
    }

    // ignore: avoid_print
    print(
      'sunucu çeviri sorusu: ${rows.length}\n'
      'yabancı dilde çeldirici: ${offLanguage.length}\n'
      'doğru cevabı dil ele veren: ${givenAway.length}\n'
      'tutarsız: ${inconsistent.length}',
    );
    for (final line in offLanguage.take(40)) {
      // ignore: avoid_print
      print('  $line');
    }
    for (final id in givenAway.take(40)) {
      // ignore: avoid_print
      print('  answer-language-leak: $id');
    }

    expect(
      offLanguage,
      isEmpty,
      reason:
          'Bu sorularda çeldiricilerden biri doğru cevabın dilinde değil; '
          'dil farkı bilgi gerektirmeyen bir ipucudur:\n'
          '${offLanguage.join("\n")}',
    );
    expect(givenAway, isEmpty, reason: givenAway.join('\n'));
  });
}

/// Supabase'in indirdiği CSV: başlık satırı + tırnaklı alanlar, alan içi
/// tırnak `""` ile kaçırılır ve alanlar satır sonu içerebilir.
List<Map<String, String>> _parseCsv(String raw) {
  final rows = <List<String>>[];
  var field = StringBuffer();
  var row = <String>[];
  var inQuotes = false;

  for (var i = 0; i < raw.length; i++) {
    final ch = raw[i];
    if (inQuotes) {
      if (ch == '"') {
        if (i + 1 < raw.length && raw[i + 1] == '"') {
          field.write('"');
          i++;
        } else {
          inQuotes = false;
        }
      } else {
        field.write(ch);
      }
      continue;
    }
    switch (ch) {
      case '"':
        inQuotes = true;
      case ',':
        row.add(field.toString());
        field = StringBuffer();
      case '\r':
        break;
      case '\n':
        row.add(field.toString());
        field = StringBuffer();
        rows.add(row);
        row = <String>[];
      default:
        field.write(ch);
    }
  }
  if (field.isNotEmpty || row.isNotEmpty) {
    row.add(field.toString());
    rows.add(row);
  }
  if (rows.isEmpty) return const [];

  final header = rows.first.map((h) => h.trim()).toList();
  return [
    for (final line in rows.skip(1))
      if (line.length >= header.length)
        {for (var i = 0; i < header.length; i++) header[i]: line[i]},
  ];
}
