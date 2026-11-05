// Yeni sorular 3 (2026-11-14) bekçisi.
//
// Teknolojî, Edebiyat, Sînema, Muzîk, Paradigma, Siyaset, Cografya, Cîhan,
// Dîrok ve Çand havuzlarını ~700'e taşımak için `yeni3_2026_11_14_questions.json`
// bu on kategoriye soru ekler; sunucu eşi `supabase/2026-11-14_yeni_sorular_3.sql`, geri alma dosyası
// `supabase/geri_al/2026-11-14_yeni_sorular_3_geri.sql`.
//
// 2026-11-18: 821 sorunun 7'si yerel JSON'dan ÇIKARILDI (6'sında doğru cevap
// soru metninde yazıyordu, 1'i `edit_dirok_0001` ile aynı metinli tekrardı) ve
// sunucuda `supabase/2026-11-18_yeni_sorular_3_eleme.sql` ile elenir
// (`is_approved = false`, `review_status = 'rejected'`; satır silinmez). Alıntı
// tırnakları düz çift tırnağa çevrildi; sunucu eşi
// `supabase/2026-11-18_yeni_sorular_3_tirnak.sql`. Uygulanmış 11-14 göçü
// DEĞİŞTİRİLMEDİ: o hâlâ 821 satır ekler; yerel banka = 821 - 7 = 814.
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
  final elemeSql = File(
    'supabase/2026-11-18_yeni_sorular_3_eleme.sql',
  ).readAsStringSync();
  final elemeGeri = File(
    'supabase/geri_al/2026-11-18_yeni_sorular_3_eleme_geri.sql',
  ).readAsStringSync();
  final tirnakSql = File(
    'supabase/2026-11-18_yeni_sorular_3_tirnak.sql',
  ).readAsStringSync();
  final tirnakGeri = File(
    'supabase/geri_al/2026-11-18_yeni_sorular_3_tirnak_geri.sql',
  ).readAsStringSync();

  // `('yerel_id', 'uuid'::uuid, ...` ile başlayan göç satırları.
  const sqlString = r"'((?:[^']|'')*)'";
  String unescape(String v) => v.replaceAll("''", "'");
  final elemeIds = RegExp(
    "^  \\('(r15_[A-Za-z0-9_]+)', '([0-9a-f-]{36})'::uuid, $sqlString, $sqlString\\)",
    multiLine: true,
  ).allMatches(elemeSql).map((m) => m.group(1)!).toList();

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

  test('SQL göçü 821 satır ekler; yerel banka = 821 - eleme göçü', () {
    final insertedIds = RegExp(
      r"^\('([0-9a-f-]{36})', \(select id from categories",
      multiLine: true,
    ).allMatches(sql).map((m) => m.group(1)!).toList();
    expect(insertedIds.length, 821);
    expect(insertedIds.length, bank.length + elemeIds.length);
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

  test('eleme göçü yalnız yerelden çıkarılan paket-3 sorularını eler', () {
    final local = bank.map((q) => q['id'] as String).toSet();
    expect(elemeIds.length, 7);
    expect(elemeIds.toSet().length, 7);
    for (final id in elemeIds) {
      expect(local.contains(id), isFalse, reason: '$id hâlâ yerel bankada');
    }
    expect(
      elemeSql,
      contains("is_approved = false, review_status = 'rejected'"),
    );
    expect(elemeSql, contains("q.prompt = r.prompt"));
    expect(elemeSql, contains('begin;'));
    expect(elemeSql, contains('commit;'));
    expect(elemeSql, isNot(contains('delete from')));
    expect(elemeSql, isNot(contains('drop ')));
    // Geri alma aynı kimliklere dokunur ve başka bir şeye dokunmaz.
    final geriIds = RegExp(
      "^  \\('(r15_[A-Za-z0-9_]+)', '([0-9a-f-]{36})'::uuid",
      multiLine: true,
    ).allMatches(elemeGeri).map((m) => m.group(1)!).toList();
    expect(geriIds, elemeIds);
    expect(
      elemeGeri,
      contains("is_approved = true, review_status = 'approved'"),
    );
  });

  test('tırnak göçü yerel bankayla birebir; geri alma tersi', () {
    final byId = {for (final q in bank) q['id'] as String: q};
    final row = RegExp(
      "^  \\('(r15_[A-Za-z0-9_]+)', '([0-9a-f-]{36})'::uuid, '([a-z_]+)', "
      "$sqlString, $sqlString\\)",
      multiLine: true,
    );
    final forward = row.allMatches(tirnakSql).toList();
    final backward = row.allMatches(tirnakGeri).toList();
    expect(forward.length, 357);
    expect(backward.length, forward.length);
    const field = {
      'prompt': 'prompt',
      'explanation': 'explanationKu',
      'explanation_ku': 'explanationKu',
      'explanation_tr': 'explanationTr',
    };
    for (var i = 0; i < forward.length; i++) {
      final m = forward[i];
      final id = m.group(1)!;
      final col = m.group(3)!;
      final eski = unescape(m.group(4)!);
      final yeni = unescape(m.group(5)!);
      final q = byId[id];
      expect(q, isNotNull, reason: '$id yerel bankada yok (elenmiş soru?)');
      expect(field.containsKey(col), isTrue, reason: 'beklenmeyen sütun $col');
      // Yeni metin yerel bankadaki metin; eski metinde ev biçimine aykırı
      // tırnak vardı, yenide yok.
      expect(q![field[col]], yeni, reason: '$id.$col yerel ile uyuşmuyor');
      expect(eski, isNot(yeni), reason: '$id.$col boş değişiklik');
      expect(
        RegExp(r'[«»\u201C\u201D]').hasMatch(yeni),
        isFalse,
        reason: '$id.$col yeni metinde eğri tırnak var',
      );
      // Geri alma satırı eski/yeni yer değiştirmiş aynı satır.
      final b = backward[i];
      expect(b.group(1), id);
      expect(b.group(3), col);
      expect(unescape(b.group(4)!), yeni);
      expect(unescape(b.group(5)!), eski);
    }
    for (final sqlText in [tirnakSql, tirnakGeri]) {
      expect(sqlText, contains('begin;'));
      expect(sqlText, contains('commit;'));
      expect(sqlText, contains('update questions set'));
      expect(sqlText, isNot(contains('delete from')));
      expect(sqlText, isNot(contains('drop ')));
    }
  });

  test('kategori başına eklenen soru sayıları sabit', () {
    final counts = <String, int>{};
    for (final q in bank) {
      counts.update(q['category'] as String, (n) => n + 1, ifAbsent: () => 1);
    }
    // 821 - 7 elenen: Çand 53->52, Cîhan 51->50, Dîrok 122->121,
    // Edebiyat 67->65 (iki soru), Teknolojî 123->121 (iki soru).
    expect(bank.length, 814);
    expect(counts, {
      'Cografya': 81,
      'Cîhan': 50,
      'Dîrok': 121,
      'Edebiyat': 65,
      'Muzîk': 77,
      'Paradigma': 102,
      'Siyaset': 63,
      'Sînema': 82,
      'Teknolojî': 121,
      'Çand': 52,
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
