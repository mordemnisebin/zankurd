// Yeni sorular 3 (2026-11-14) bekçisi.
//
// Teknolojî, Edebiyat, Sînema, Muzîk, Paradigma, Siyaset, Cografya, Cîhan,
// Dîrok ve Çand havuzlarını ~700'e taşımak için `yeni3_2026_11_14_questions.json`
// bu on kategoriye soru ekler; sunucu eşi `supabase/2026-11-14_yeni_sorular_3.sql`, geri alma dosyası
// `supabase/geri_al/2026-11-14_yeni_sorular_3_geri.sql`.
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
                  'assets/data/yeni3_2026_11_14_questions.json',
                ).readAsStringSync(),
              )
              as List)
          .cast<Map<String, dynamic>>();
  final sql = File('supabase/2026-11-14_yeni_sorular_3.sql').readAsStringSync();
  final rollback = File(
    'supabase/geri_al/2026-11-14_yeni_sorular_3_geri.sql',
  ).readAsStringSync();

  test('hedef kategorilerde, benzersiz kimlikle soru var', () {
    final categories = bank.map((q) => q['category']).toSet();
    expect(categories, {
      'Cografya',
      'Cîhan',
      'Dîrok',
      'Edebiyat',
      'Muzîk',
      'Paradigma',
      'Siyaset',
      'Sînema',
      'Teknolojî',
      'Çand',
    });
    final ids = bank.map((q) => q['id'] as String).toList();
    expect(ids.toSet().length, ids.length);
    expect(ids.every((id) => id.startsWith('r15_')), isTrue);
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

  test('kategori başına eklenen soru sayıları sabit', () {
    final counts = <String, int>{};
    for (final q in bank) {
      counts.update(q['category'] as String, (n) => n + 1, ifAbsent: () => 1);
    }
    expect(bank.length, 536);
    expect(counts, {
      'Cografya': 60,
      'Cîhan': 21,
      'Dîrok': 90,
      'Edebiyat': 45,
      'Muzîk': 51,
      'Paradigma': 70,
      'Siyaset': 28,
      'Sînema': 50,
      'Teknolojî': 96,
      'Çand': 25,
    });
  });

  test('hiçbir yeni soru başka bankadaki bir sorunun aynısı değil', () {
    String norm(String s) =>
        s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9çêîûşöüğı]+'), ' ').trim();
    final mine = bank.map((q) => q['id'] as String).toSet();
    final others = <String>{};
    for (final f in Directory('assets/data').listSync().whereType<File>()) {
      if (!f.path.endsWith('.json')) continue;
      final decoded = jsonDecode(f.readAsStringSync());
      if (decoded is! List) continue;
      for (final q in decoded) {
        if (q is Map && q['prompt'] is String && !mine.contains(q['id'])) {
          others.add('${q['category']}|${norm(q['prompt'] as String)}');
        }
      }
    }
    final own = <String>{};
    for (final q in bank) {
      final key = '${q['category']}|${norm(q['prompt'] as String)}';
      expect(others.contains(key), isFalse, reason: '${q['id']} bankada var');
      expect(own.add(key), isTrue, reason: '${q['id']} kendi içinde tekrar');
    }
  });
}
