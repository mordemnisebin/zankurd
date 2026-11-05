// Yeni sorular 4 (2026-11-17) bekçisi.
//
// Teknolojî, Edebiyat, Sînema, Muzîk, Paradigma, Siyaset, Cografya, Cîhan,
// Dîrok ve Çand havuzlarını ~700'e yaklaştırmak için `tool/data/yeni4_2026_11_17_server_only.json`
// (UYGULAMAYA PAKETLENMEZ: rekabetçi modlar bu sunucu-yalnız havuzdan çeker, cevap anahtarı
// istemcide olmasın diye; göç satırları `server_only = true`)
// bu on kategoriye soru ekler; sunucu eşi `supabase/2026-11-17_yeni_sorular_4.sql`, geri alma dosyası
// `supabase/geri_al/2026-11-17_yeni_sorular_4_geri.sql`.
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
                  'tool/data/yeni4_2026_11_17_server_only.json',
                ).readAsStringSync(),
              )
              as List)
          .cast<Map<String, dynamic>>();
  final sql = File('supabase/2026-11-17_yeni_sorular_4.sql').readAsStringSync();
  final rollback = File(
    'supabase/geri_al/2026-11-17_yeni_sorular_4_geri.sql',
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
      'Çand',
    });
    final ids = bank.map((q) => q['id'] as String).toList();
    expect(ids.toSet().length, ids.length);
    expect(ids.every((id) => id.startsWith('r16_')), isTrue);
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

  test('SQL göçü ile sunucu-yalnız kaynak aynı sayıda soruyu taşıyor', () {
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
    expect(bank.length, 175);
    expect(counts, {
      'Cografya': 19,
      'Cîhan': 10,
      'Dîrok': 30,
      'Edebiyat': 14,
      'Muzîk': 15,
      'Paradigma': 22,
      'Siyaset': 24,
      'Sînema': 29,
      'Çand': 12,
    });
  });

  test('paket 4 uygulama paketinde YOK; göçte her satır server_only = true', () {
    final ids = bank.map((q) => q['id'] as String).toSet();
    String norm(String s) =>
        s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9çêîûşöüğı]+'), ' ').trim();
    final prompts = bank.map((q) => norm(q['prompt'] as String)).toSet();
    for (final f in Directory('assets').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.json')) continue;
      final raw = f.readAsStringSync();
      expect(raw.contains('r16_'), isFalse, reason: '${f.path} r16_ içeriyor');
      final decoded = jsonDecode(raw);
      if (decoded is! List) continue;
      for (final q in decoded) {
        if (q is! Map) continue;
        expect(ids.contains(q['id']), isFalse, reason: '${f.path} ${q['id']}');
        if (q['prompt'] is String) {
          expect(
            prompts.contains(norm(q['prompt'] as String)),
            isFalse,
            reason: '${f.path} ${q['id']} paket-4 metni uygulamada',
          );
        }
      }
    }
    for (final p in [
      'pubspec.yaml',
      'lib/src/data/question_bank_assets.dart',
    ]) {
      expect(File(p).readAsStringSync().contains('yeni4'), isFalse, reason: p);
    }
    expect(
      sql,
      contains(
        'alter table public.questions add column if not exists server_only boolean not null default false;',
      ),
    );
    final rows = RegExp(
      r"^\('[0-9a-f-]{36}', \(select id from categories.*, true\)[,;]?$",
      multiLine: true,
    ).allMatches(sql).length;
    expect(
      rows,
      bank.length,
      reason: 'her göç satırı server_only = true olmalı',
    );
  });

  test('içerik kuralları: carrier, cevap sızıntısı, tırnak, tekrar', () {
    final turkishOnly = RegExp(r'[ığöüİ]');
    final quoted = RegExp(r'"[^"]*"|“[^”]*”|«[^»]*»|\([^)]*\)');
    final forbidden = RegExp('[«»“”„‟]');
    final singleQuoted = RegExp(
      r"(?<![\p{L}\p{N}])'[^'\n]{1,70}'",
      unicode: true,
    );
    final singleQuoted2 = RegExp(r"(?:(?<=\s)|^)'[^'\s][^']{0,40}'");
    String fold(String v) => v
        .toLowerCase()
        .replaceAll('ı', 'i')
        .replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    String ws(String v) =>
        v.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    final seen = <String>{};
    for (final q in bank) {
      final id = q['id'];
      final prompt = q['prompt'] as String;
      expect(
        turkishOnly.hasMatch(prompt.replaceAll(quoted, ' ')),
        isFalse,
        reason: '$id KU prompt Türkçe harf: $prompt',
      );
      for (final (p, a) in [
        (prompt, q['correctAnswer'] as String),
        (q['promptTr'] as String, q['correctAnswerTr'] as String),
      ]) {
        final fa = fold(a);
        expect(
          fa.isNotEmpty && ' ${fold(p)} '.contains(' $fa '),
          isFalse,
          reason: '$id cevap prompt içinde: $a',
        );
      }
      final c = ws(q['correctAnswer'] as String);
      if (c.length >= 6) {
        expect(ws(prompt).contains(c), isFalse, reason: '$id cevap sızıyor');
      }
      final fields = <String>[
        prompt,
        q['promptTr'] as String,
        q['explanation'] as String,
        q['explanationKu'] as String,
        q['explanationTr'] as String,
        ...(q['answers'] as List).cast<String>(),
        ...(q['answersTr'] as List).cast<String>(),
      ];
      for (final f in fields) {
        expect(
          forbidden.hasMatch(f) ||
              singleQuoted.hasMatch(f) ||
              singleQuoted2.hasMatch(f),
          isFalse,
          reason: '$id eski alıntı biçimi: $f',
        );
      }
      final key = prompt
          .toLowerCase()
          .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ')
          .trim();
      expect(seen.add(key), isTrue, reason: '$id kendi içinde tekrar');
    }
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
