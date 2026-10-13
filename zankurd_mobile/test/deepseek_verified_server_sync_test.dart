/// Doğrulanmış DeepSeek sorularının sunucu göçü — sözleşme bekçisi.
///
/// ## Kusur
///
/// `deepseek_verified_2026_09_30_questions.json` (822 soru) uygulamada açıldı,
/// ama oda ve düello soruları sunucudan çeker. `2026-09-30_cihan_and_science.sql`
/// bunlardan yalnız Cîhan'dakileri (300) ekledi; Teknolojî ve Kürt
/// kategorilerindekiler (522; sonradan 509, artı 30 bilim sorusu) sunucuda yoktu: oyuncu tek başına oynarken
/// gördüğü soruyu odada/düelloda hiç görmüyordu.
///
/// ## Niçin sessiz kalırdı
///
/// Sunucu ile yerel banka ayrı iki dünyadır: biri öbüründen habersiz
/// büyür. Yeni bir doğrulanmış soru eklenip göç yeniden üretilmezse hiçbir
/// derleme ya da widget testi kızarmaz; eksik ancak canlı bir odada
/// "bu kategoride niçin hiç yeni soru çıkmıyor" diye fark edilirdi.
///
/// ## Neyi korur
///
/// * Göçteki satırlar, yerel küme (doğrulanmış dosya + kaynaklı bilim
///   soruları) ile sunucuda ZATEN olanlar
///   (`cihan_and_science.sql` ve `sinema_category_and_questions.sql`)
///   arasındaki farkın birebir kendisi (her kategori için istem kümesi):
///   yeni doğrulanmış soru eklenip göç yeniden üretilmezse test kızarır.
/// * Göçün hiçbir kimliği daha önce uygulanmış iki göçte geçmiyor: tekrar
///   ekleme yok.
/// * Her satır `on conflict (id) do nothing` ve kategori adıyla aranır;
///   kategori oluşturmaz; eksik kategori ve sayı doğrulama bloğu var.
/// * Yalnız çoktan seçmeli/doğru-yanlış şeması: dört şık, `correct_option`
///   A–D.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _verified = 'assets/data/deepseek_verified_2026_09_30_questions.json';
const _science = 'assets/data/bilim_2026_09_30_questions.json';
const _syncSql = 'supabase/2026-09-30_deepseek_verified_sync.sql';

// Yalnız satır başındaki kimlik: doğrulama bloğundaki `id in ('…')` listesi
// sayılmaz.
final _idRe = RegExp(
  r"^\('([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})'",
  multiLine: true,
);

// ('uuid', (select id from categories where name = 'Ad'), 'ku-kmr', 'istem',
final _rowRe = RegExp(
  r"^\('([0-9a-f-]{36})', \(select id from categories where name = '([^']+)'\), "
  r"'ku-kmr', '((?:[^']|'')*)', ",
  multiLine: true,
);

void main() {
  final sql = File(_syncSql).readAsStringSync();
  // Sunucuya gidecek yerel küme: doğrulanmış DeepSeek kopyası + kaynaklı bilim
  // soruları (Paradigma).
  final verified = [
    ...(jsonDecode(File(_verified).readAsStringSync()) as List),
    ...(jsonDecode(File(_science).readAsStringSync()) as List),
  ].cast<Map<String, dynamic>>();
  final rows = _rowRe.allMatches(sql).toList();

  test('göç dosyası var ve satırlar ayrıştırılabiliyor', () {
    expect(rows, isNotEmpty);
    expect(_idRe.allMatches(sql).length, rows.length);
  });

  test(
    'göç = doğrulanmış dosya eksi sunucuda zaten olanlar (kategori başına)',
    () {
      // Sunucuda zaten olan sorular: canlıda uygulanmış iki göçün istemleri.
      final appliedSql = [
        'supabase/2026-09-30_cihan_and_science.sql',
        'supabase/2026-09-30_sinema_category_and_questions.sql',
      ].map((f) => File(f).readAsStringSync()).join('\n');
      final expectedByCategory = <String, Set<String>>{};
      for (final q in verified) {
        final prompt = (q['prompt'] as String).trim().replaceAll("'", "''");
        if (appliedSql.contains("'$prompt'")) continue; // sunucuda var
        expectedByCategory
            .putIfAbsent(q['category'] as String, () => <String>{})
            .add(prompt);
      }
      final sqlByCategory = <String, Set<String>>{};
      for (final m in rows) {
        sqlByCategory
            .putIfAbsent(m.group(2)!, () => <String>{})
            .add(m.group(3)!);
      }
      expect(sqlByCategory.keys.toSet(), expectedByCategory.keys.toSet());
      for (final category in expectedByCategory.keys) {
        expect(
          sqlByCategory[category],
          expectedByCategory[category],
          reason:
              '$category: göçteki istemler yerel doğrulanmış kümeyle ayrışmış; '
              'tool/sync_deepseek_verified_to_server.py yeniden çalıştırılmalı',
        );
      }
      final expected = expectedByCategory.values.fold<int>(
        0,
        (sum, prompts) => sum + prompts.length,
      );
      expect(rows.length, expected);
    },
  );

  test('kimlikler benzersiz ve daha önce uygulanmış göçlerde geçmiyor', () {
    final ids = rows.map((m) => m.group(1)!).toList();
    expect(ids.toSet().length, ids.length, reason: 'yinelenen kimlik');
    for (final applied in [
      'supabase/2026-09-30_cihan_and_science.sql',
      'supabase/2026-09-30_sinema_category_and_questions.sql',
    ]) {
      final appliedIds = _idRe
          .allMatches(File(applied).readAsStringSync())
          .map((m) => m.group(1)!)
          .toSet();
      expect(
        ids.where(appliedIds.contains),
        isEmpty,
        reason: '$applied ile çakışma: sunucuda zaten var, tekrar eklenmemeli',
      );
    }
  });

  test(
    'ekleme güvenli: çakışmada atlar, kategori oluşturmaz, sayıyı doğrular',
    () {
      final code = sql
          .split('\n')
          .where((l) => !l.trimLeft().startsWith('--'))
          .join('\n');
      expect(code, contains('on conflict (id) do nothing'));
      expect(code, isNot(contains('insert into categories')));
      expect(code.toLowerCase(), isNot(contains('delete ')));
      expect(code, contains('Eksik kategori'));
      expect(code, contains('<> ${rows.length}'));
      expect(code.trimRight(), endsWith('commit;'));
    },
  );

  test('yalnız dört şıklı çoktan seçmeli şemaya uygun', () {
    final typeCount = RegExp("'multiple_choice'").allMatches(sql).length;
    expect(typeCount, rows.length);
    expect(sql, isNot(contains("'true_false'")));
    final correct = RegExp(r"'([ABCD])', '", multiLine: true);
    expect(correct.allMatches(sql).length, greaterThanOrEqualTo(rows.length));
  });

  test('applied.md satırı var', () {
    final applied = File('supabase/applied.md').readAsStringSync();
    expect(applied, contains('2026-09-30_deepseek_verified_sync.sql'));
  });
}
