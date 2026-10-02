/// Üç alt konunun kartı görünür kalmalı: «alt konu» bankası + sunucu göçü.
///
/// ## Kusur
///
/// `SubcategoryConfig.visibleFor` bir alt konuyu yalnız anahtar kelimeyle
/// eşleşen oynanabilir soru sayısı >= 20 ise gösterir. 2026-09-30 sonunda
/// üç konu eşiğin altında kaldığı için kartı HİÇ görünmüyordu: Muzîk ›
/// Muzîka Nûjen (15), Teknolojî › Programkirin (16), Sînema › Yılmaz Güney û
/// Klasîk (18). Kullanıcıya hata gösterilmez: kart yalnız yoktur.
///
/// ## Niçin sessiz kalırdı
///
/// Gizleme kasıtlı bir dürüstlük (bkz. `kMinSubcategoryQuestions`); bu
/// yüzden bir konu eşiğin altına DÜŞTÜĞÜNDE de hiçbir test kızarmaz. Soru
/// emekliye ayrılır ya da bir anahtar kelime daraltılırsa kart bir sürümde
/// sessizce kaybolurdu.
///
/// ## Neyi korur
///
/// * Üç konu ÜRETİM bankasıyla eşiği geçer ve `visibleFor` onları döner.
/// * Yeni 17 soru gerçekten hedef konularına düşer (Muzîka Nûjen ≥ 7,
///   Programkirin ≥ 5 yeni soruyla); eşik "komşudan" değil kendi
///   sorularıyla sağlanır.
/// * Sunucu göçü (`2026-10-01_altkonu_sync.sql`) banka dosyasıyla birebir
///   aynı 17 istemi taşır, kategori oluşturmaz, `on conflict` ve sayı
///   doğrulaması vardır; `applied.md`de satırı durur.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/config/subcategory_config.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/data/question_bank_loader.dart';

const _bank = 'assets/data/altkonu_2026_10_01_questions.json';
const _sql = 'supabase/2026-10-01_altkonu_sync.sql';

const _targets = <(String, String)>[
  ('Muzîk', 'nujen'),
  ('Teknolojî', 'programkirin'),
  ('Sînema', 'yilmaz_guney'),
];

void main() {
  late MockZanKurdRepository repository;

  setUp(() {
    // Yükleyiciyi tetikle (test ortamında senkron dosya okuması).
    expect(QuestionBankLoader.instance.allQuestions.length, greaterThan(1000));
    repository = MockZanKurdRepository();
  });

  test('üç alt konu eşiği geçer ve kartı görünür', () {
    final playable = repository.playableQuestions.toList();
    for (final (category, id) in _targets) {
      final count = playable
          .where(
            (q) =>
                q.category == category &&
                SubcategoryConfig.getSubcategoryId(q) == id,
          )
          .length;
      expect(
        count,
        greaterThanOrEqualTo(SubcategoryConfig.kMinSubcategoryQuestions),
        reason: '$category › $id yalnız $count oynanabilir soruyla kaldı',
      );
      expect(
        SubcategoryConfig.visibleFor(category, playable).map((s) => s.id),
        contains(id),
        reason: '$category › $id kartı gizli kaldı',
      );
    }
  });

  test('yeni sorular hedef alt konularına düşer', () {
    final byId = {for (final q in repository.playableQuestions) q.id: q};
    final bank = (jsonDecode(File(_bank).readAsStringSync()) as List)
        .cast<Map<String, dynamic>>();
    expect(bank, hasLength(17));
    final landed = <String, int>{};
    for (final raw in bank) {
      final q = byId[raw['id']];
      expect(q, isNotNull, reason: '${raw['id']} oynanabilir değil');
      final id = SubcategoryConfig.getSubcategoryId(q!);
      landed['${q.category}/$id'] = (landed['${q.category}/$id'] ?? 0) + 1;
    }
    expect(landed['Muzîk/nujen'], greaterThanOrEqualTo(7));
    expect(landed['Teknolojî/programkirin'], greaterThanOrEqualTo(5));
    // Yılmaz Güney û Klasîk'e düşenler iki «Yilmaz Guney» sorusu; Rashomon ve
    // Bisiklet Hırsızları «fîlm/derhêner» anahtarlarıyla Filmler & Yönetmenler'e
    // gider (bilinen, kabul edilen: o konunun eşiği bankanın önceki 18
    // sorusuyla zaten 20'ye bu iki soruyla varır).
    expect(landed['Sînema/yilmaz_guney'], greaterThanOrEqualTo(2));
  });

  group('sunucu göçü', () {
    late String sql;
    setUp(() => sql = File(_sql).readAsStringSync());

    test('göç = banka dosyasındaki 17 istem', () {
      final bank = (jsonDecode(File(_bank).readAsStringSync()) as List)
          .cast<Map<String, dynamic>>();
      final rows = RegExp(
        r"^\('([0-9a-f-]{36})', \(select id from categories where name = "
        r"'([^']+)'\), 'ku-kmr', '((?:[^']|'')*)', ",
        multiLine: true,
      ).allMatches(sql).toList();
      expect(rows, hasLength(bank.length));
      expect(
        {for (final m in rows) '${m.group(2)}|${m.group(3)}'},
        {
          for (final q in bank)
            '${q['category']}|${(q['prompt'] as String).replaceAll("'", "''")}',
        },
        reason: 'banka değişti, tool/sync_altkonu_to_server.py yeniden koşmalı',
      );
      expect(rows.map((m) => m.group(1)).toSet(), hasLength(rows.length));
    });

    test('ekleme güvenli: çakışmada atlar, kategori oluşturmaz, sayar', () {
      final code = sql
          .split('\n')
          .where((l) => !l.trimLeft().startsWith('--'))
          .join('\n');
      expect(code, contains('on conflict (id) do nothing'));
      expect(code, isNot(contains('insert into categories')));
      expect(code.toLowerCase(), isNot(contains('delete ')));
      expect(code, contains('Eksik kategori'));
      expect(code, contains('<> 17'));
      expect(code.trimRight(), endsWith('commit;'));
    });

    test('applied.md satırı var', () {
      expect(
        File('supabase/applied.md').readAsStringSync(),
        contains('2026-10-01_altkonu_sync.sql'),
      );
    });
  });
}
