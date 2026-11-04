// Yeni sorular (2026-11-07) bekçisi.
//
// Sînema, Paradigma, Siyaset, Muzîk ve Edebiyat havuzları en ince
// kategorilerdi. `yeni_2026_11_07_questions.json` bu beş kategoriye soru
// ekler; sunucu eşi `supabase/2026-11-07_yeni_sorular.sql`, geri alma dosyası
// `supabase/geri_al/2026-11-07_yeni_sorular_geri.sql`.
//
// Bu dosya sessizce bozulabilecek şeyleri tutar:
//  * yerel banka ile SQL aynı kimlik kümesini taşımalı (biri eksik kalırsa
//    çevrimdışı oyuncu ile oda/düello oyuncusu farklı havuz görür);
//  * geri alma yalnız bu göçün kimliklerini silmeli, başka bir şeye dokunmamalı;
//  * her soruda dört ayrı şık, şıklar arasında doğru cevap, Kurmancî ve
//    Türkçe alanlar dolu olmalı; açıklamada "Kaynak:" satırı olmamalı;
//  * doğru şık konumu dengeli kalmalı (taslakta hep aynı konumda çıkıyordu).
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final bank =
      (jsonDecode(
                File(
                  'assets/data/yeni_2026_11_07_questions.json',
                ).readAsStringSync(),
              )
              as List)
          .cast<Map<String, dynamic>>();
  final sql = File('supabase/2026-11-07_yeni_sorular.sql').readAsStringSync();
  final rollback = File(
    'supabase/geri_al/2026-11-07_yeni_sorular_geri.sql',
  ).readAsStringSync();

  test('beş hedef kategoride, benzersiz kimlikle soru var', () {
    final categories = bank.map((q) => q['category']).toSet();
    expect(categories, {'Sînema', 'Paradigma', 'Siyaset', 'Muzîk', 'Edebiyat'});
    final ids = bank.map((q) => q['id'] as String).toList();
    expect(ids.toSet().length, ids.length);
    expect(ids.every((id) => id.startsWith('r12_')), isTrue);
  });

  test('her soruda dört ayrı şık ve şıklar arasında doğru cevap var', () {
    for (final q in bank) {
      final answers = (q['answers'] as List).cast<String>();
      final answersTr = (q['answersTr'] as List).cast<String>();
      expect(answers.length, 4, reason: '${q['id']}');
      expect(answers.toSet().length, 4, reason: '${q['id']} tekrar eden şık');
      expect(answersTr.length, 4, reason: '${q['id']}');
      expect(
        answers.contains(q['correctAnswer']),
        isTrue,
        reason: '${q['id']}',
      );
      expect(
        answersTr[answers.indexOf(q['correctAnswer'] as String)],
        q['correctAnswerTr'],
        reason: '${q['id']} Türkçe doğru şık aynı konumda değil',
      );
      for (final field in [
        'prompt',
        'promptTr',
        'explanationKu',
        'explanationTr',
      ]) {
        expect((q[field] as String).trim(), isNotEmpty, reason: '${q['id']}');
      }
      final text = '${q['explanationKu']} ${q['explanationTr']}'.toLowerCase();
      expect(
        RegExp(r'(kaynak|çavkanî)\s*:').hasMatch(text),
        isFalse,
        reason: '${q['id']} açıklamada kaynak satırı olmamalı',
      );
    }
  });

  test('doğru şık konumu dört şıkka dengeli dağılmış', () {
    final positions = <int, int>{0: 0, 1: 0, 2: 0, 3: 0};
    for (final q in bank) {
      final answers = (q['answers'] as List).cast<String>();
      final index = answers.indexOf(q['correctAnswer'] as String);
      positions[index] = positions[index]! + 1;
    }
    final fair = bank.length / 4;
    for (final count in positions.values) {
      expect(count, greaterThan(fair * 0.7));
      expect(count, lessThan(fair * 1.3));
    }
  });

  test('SQL göçü ile yerel banka aynı sayıda soruyu taşıyor', () {
    final insertedIds = RegExp(
      r"^\('([0-9a-f-]{36})', \(select id from categories",
      multiLine: true,
    ).allMatches(sql).map((m) => m.group(1)!).toList();
    expect(insertedIds.length, bank.length);
    expect(insertedIds.toSet().length, insertedIds.length);
    expect(sql, contains('on conflict (id) do nothing'));
    expect(sql, contains('begin;'));
    expect(sql, contains('commit;'));
    expect(sql, isNot(contains('create table')));
    expect(sql, isNot(contains('drop ')));
  });

  test('geri alma yalnız göçün eklediği kimlikleri siler', () {
    final inserted = RegExp(
      r"^\('([0-9a-f-]{36})', \(select id from categories",
      multiLine: true,
    ).allMatches(sql).map((m) => m.group(1)!).toSet();
    final removed = RegExp(
      r"'([0-9a-f-]{36})'",
    ).allMatches(rollback).map((m) => m.group(1)!).toSet();
    expect(removed, inserted);
    expect(RegExp(r'delete from questions').allMatches(rollback).length, 1);
    expect(rollback, contains('begin;'));
    expect(rollback, contains('commit;'));
  });
}
