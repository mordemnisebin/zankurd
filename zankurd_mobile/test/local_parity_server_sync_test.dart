/// Yerel banka ↔ sunucu eşitleme göçlerinin sözleşme bekçisi.
///
/// ## Kusur
///
/// Oda ve düello soruları sunucudaki `questions` tablosundan oynanır, ama
/// kaynak doğru yerel, denetlenmiş bankadır. İkisi birbirinden habersiz
/// büyüdü: yerelde ~2500 oynanabilir sorunun yalnız ~1100'ü sunucudaydı
/// (Siyaset 0/64, Edebiyat 6/152…), ters yönde de yerelde EMEKLİ edilmiş
/// bazı sorular sunucuda onaylı kalmıştı (2026-10-01).
/// `tool/sync_local_parity_to_server.py` farkı iki göç dosyasına döker:
///
///   * `2026-10-01_local_parity_sync_<kategori>.sql` — kategori başına,
///     sunucuda eksik oynanabilir yerel soruları (uuid5 kimlikli) ekler.
///     Görselli sorular BİLEREK yok: mağazadaki eski sürümlerde yeni görsel
///     dosyaları yok (kırık görsel); 2.0.0 sonrası ayrı göçle;
///   * `2026-10-01_local_parity_update_<kategori>.sql` — uuid5 eşli bayat
///     satırları yerel sürüme çeker;
///   * `2026-10-01_retired_local_unapprove.sql` — yerelde emekli/oynanamaz
///     olup sunucuda hâlâ onaylı duran satırları onaydan çıkarır.
///
/// ## Niçin sessiz kalırdı
///
/// Göç dosyaları salt metin; sunucuyu bilen tek taraf araçtır. Araç yanlış
/// bir satır üretse (oynanamaz bir soru ekleme, oynanabilir bir soruyu
/// onaydan çıkarma, kimlik şemasını bozma) hiçbir derleme ya da widget testi
/// kızarmazdı; hata ancak canlıda bir odada görünürdü.
///
/// ## Neyi korur
///
/// Sunucu olmadan doğrulanabilen her şeyi:
///
/// * Eklenen her satır, bankada ŞU AN oynanabilir bir yerel sorudur; kimliği
///   `uuid5(ad alanı, 'zankurd-local:' + yerelId)`; kategori ve soru metni
///   yerelle aynıdır. Yani emekli ya da reddedilmiş bir soru eklenemez.
/// * Onaydan çıkarılan her satırın yerel karşılığı oynanamaz; oynanabilir bir
///   yerel soruyla aynı metni taşımaz.
/// * İki dosya birbirinin sorusuna dokunmaz; kimlikler benzersiz.
/// * Ekleme güvenli (`on conflict do nothing`, silme yok, kategori
///   oluşturmaz) ve doğrulama bloğu satır sayısını bilir.
///
/// Sunucudaki mevcut hâl göç üretilirken okunur; bu bekçi onu denetleyemez
/// (bunun için aracı `--check` ile yeniden çalıştır).
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/question_bank_loader.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/services/question_content_policy.dart';

const _syncPrefix = '2026-10-01_local_parity_sync_';
const _updatePrefix = '2026-10-01_local_parity_update_';
const _retiredSql = 'supabase/2026-10-01_retired_local_unapprove.sql';
const _namespace = '5a1e2b7c-3d4f-4e60-9a8b-2c1d0f9e8a77';

/// Ekleme göçündeki kategorisi sonradan yerelde değiştirilen sorular:
/// yerel id -> ekleme dosyasındaki ESKİ kategori. Düzeltme göçü
/// `supabase/2026-10-02_e2e_content_fixes.sql`dir.
const _recategorisedLocally = <String, String>{'offline_0757': 'Cografya'};

/// RFC 4122 sürüm 5 (SHA-1) — Python'daki `uuid.uuid5` ile aynı.
String _uuid5(String name) {
  final ns = <int>[];
  final hex = _namespace.replaceAll('-', '');
  for (var i = 0; i < hex.length; i += 2) {
    ns.add(int.parse(hex.substring(i, i + 2), radix: 16));
  }
  final digest = sha1.convert([...ns, ...utf8.encode(name)]).bytes;
  final b = List<int>.of(digest.sublist(0, 16));
  b[6] = (b[6] & 0x0f) | 0x50;
  b[8] = (b[8] & 0x3f) | 0x80;
  final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-'
      '${h.substring(16, 20)}-${h.substring(20)}';
}

String _code(String sql) =>
    sql.split('\n').where((l) => !l.trimLeft().startsWith('--')).join('\n');

// ('uuid', (select id from categories where name = 'Ad'), 'ku-kmr', 'istem', … -- yerel: id
final _insertRe = RegExp(
  r"^\('([0-9a-f-]{36})', \(select id from categories where name = '([^']+)'\), "
  r"'ku-kmr', '((?:[^']|'')*)', .*\)[,]? -- yerel: (\S+)$",
  multiLine: true,
);

// ('uuid'::uuid, 'Kategori')[,;] -- yerel: id (neden, yol)
final _retiredRe = RegExp(
  r"^  \('([0-9a-f-]{36})'::uuid, '([^']+)'\)[,;] -- yerel: (\S+) \(",
  multiLine: true,
);

/// `supabase/` altında verilen önekle başlayan göçler: ad -> içerik.
Map<String, String> _files(String prefix) => {
  for (final f in Directory('supabase').listSync().whereType<File>())
    if (f.uri.pathSegments.last.startsWith(prefix))
      f.uri.pathSegments.last: f.readAsStringSync(),
};

void main() {
  const policy = QuestionContentPolicy();
  late Map<String, QuizQuestion> byId;
  late Map<String, String> syncFiles;
  late Map<String, String> updateFiles;
  late String sync; // bütün ekleme dosyaları birleşik
  late String retired;

  setUpAll(() {
    byId = {for (final q in QuestionBankLoader.instance.allQuestions) q.id: q};
    syncFiles = _files(_syncPrefix);
    updateFiles = _files(_updatePrefix);
    sync = syncFiles.values.join('\n');
    retired = File(_retiredSql).readAsStringSync();
  });

  test('eklenen her satır bankada şu an oynanabilir bir yerel sorudur', () {
    final rows = _insertRe.allMatches(sync).toList();
    expect(rows, isNotEmpty);
    final ids = <String>{};
    final locals = <String>{};
    for (final m in rows) {
      final id = m.group(1)!;
      final category = m.group(2)!;
      final prompt = m.group(3)!.replaceAll("''", "'");
      final localId = m.group(4)!;
      final q = byId[localId];
      expect(
        q,
        isNotNull,
        reason: '$localId bankada yok (silinmiş/yeniden adlandırılmış)',
      );
      expect(
        id,
        _uuid5('zankurd-local:$localId'),
        reason: '$localId: kimlik uuid5 değil',
      );
      expect(
        policy.isPlayable(q!),
        isTrue,
        reason:
            '$localId oynanabilir değil (emekli/reddedilmiş) ama sunucuya ekleniyor',
      );
      // 2026-10-02: tek bilinçli ayrışma. offline_0757 ('"su" bi Kurmancî
      // çi ye?') ekleme göçünde Cografya idi; sözcük çevirisi olduğu için
      // yerelde Ziman'a alındı ve sunucuda
      // `2026-10-02_e2e_content_fixes.sql` ile alınır (aşağıdaki test
      // göçün varlığını denetler). Başka ayrışma hâlâ kusurdur.
      final oldCategory = _recategorisedLocally[localId];
      if (oldCategory == null) {
        expect(q.category, category, reason: '$localId: kategori ayrışmış');
      } else {
        expect(category, oldCategory, reason: '$localId: eski kategori');
      }
      expect(q.prompt.trim(), prompt, reason: '$localId: soru metni ayrışmış');
      expect(
        q.type == QuestionType.fillInBlank ||
            q.type == QuestionType.wordOrdering ||
            q.type == QuestionType.visual,
        isFalse,
        reason: '$localId: tür sunucu şemasına sığmaz ya da görselli',
      );
      expect(
        q.hasImage,
        isFalse,
        reason: '$localId görselli: görselli sorular 2.0.0 sonrası eklenir',
      );
      expect(ids.add(id), isTrue, reason: 'yinelenen kimlik $id');
      expect(
        locals.add(localId),
        isTrue,
        reason: 'yinelenen yerel id $localId',
      );
    }
  });

  test(
    'her ekleme dosyası tek kategori, kendi önkoşul ve sayı doğrulamasıyla',
    () {
      expect(syncFiles, isNotEmpty);
      for (final entry in syncFiles.entries) {
        final sql = entry.value;
        final rows = _insertRe.allMatches(sql).toList();
        final n = rows.length;
        expect(n, greaterThan(0), reason: entry.key);
        final categories = rows.map((m) => m.group(2)!).toSet();
        expect(
          categories.length,
          1,
          reason: '${entry.key}: tek kategori olmalı',
        );
        expect(sql, contains('EKSİK $n ${categories.single} sorusu'));
        expect(sql, contains('<> $n then'), reason: entry.key);
        expect(sql, contains('GÖRSELLİ SORULAR BU DOSYADA YOK'));
        final code = _code(sql);
        expect(code, contains('on conflict (id) do nothing'));
        expect(code, isNot(contains('insert into categories')));
        expect(code.toLowerCase(), isNot(contains('delete ')));
        expect(code, contains('Eksik kategori'));
        expect(code.trimRight(), endsWith('commit;'));
      }
    },
  );

  test('eşitleme dosyaları uuid5 kimlikli, oynanabilir yerel sorulara ait', () {
    expect(updateFiles, isNotEmpty);
    final idRe = RegExp(
      r"^  \('([0-9a-f-]{36})'::uuid, .*\)[,;] -- yerel: (\S+)$",
      multiLine: true,
    );
    for (final entry in updateFiles.entries) {
      final rows = idRe.allMatches(entry.value).toList();
      expect(rows, isNotEmpty, reason: entry.key);
      expect(entry.value, contains('<> ${rows.length} then'));
      for (final m in rows) {
        final q = byId[m.group(2)!];
        expect(q, isNotNull, reason: '${m.group(2)} bankada yok');
        expect(m.group(1), _uuid5('zankurd-local:${q!.id}'));
        expect(policy.isPlayable(q), isTrue, reason: '${q.id} oynanamaz');
      }
      final code = _code(entry.value);
      expect(code.toLowerCase(), isNot(contains('delete ')));
      expect(code.trimRight(), endsWith('commit;'));
    }
  });

  test('onaydan çıkarılanların yerel karşılığı oynanamaz', () {
    final rows = _retiredRe.allMatches(retired).toList();
    expect(rows, isNotEmpty);
    final playablePrompts = {
      for (final q in byId.values)
        if (policy.isPlayable(q)) q.prompt.trim(),
    };
    final ids = <String>{};
    for (final m in rows) {
      final id = m.group(1)!;
      final localId = m.group(3)!;
      final q = byId[localId];
      expect(q, isNotNull, reason: '$localId bankada yok');
      expect(
        policy.isPlayable(q!),
        isFalse,
        reason: '$localId artık oynanabilir ama sunucuda onaydan çıkarılıyor',
      );
      expect(
        playablePrompts.contains(q.prompt.trim()),
        isFalse,
        reason: '$localId metni başka bir oynanabilir yerel soruda duruyor',
      );
      expect(ids.add(id), isTrue, reason: 'yinelenen kimlik $id');
    }
    expect(retired, contains('${ids.length} bilinen-kötü'));
    expect(retired, contains('<> ${ids.length} then'));
    final code = _code(retired);
    expect(code.toLowerCase(), isNot(contains('delete ')));
    expect(code, contains('set is_approved = false'));
  });

  test('iki göç birbirinin sorusuna dokunmaz', () {
    final inserted = _insertRe.allMatches(sync).map((m) => m.group(4)!).toSet();
    final unapproved = _retiredRe
        .allMatches(retired)
        .map((m) => m.group(3)!)
        .toSet();
    expect(inserted.intersection(unapproved), isEmpty);
    final insertedIds = _insertRe
        .allMatches(sync)
        .map((m) => m.group(1)!)
        .toSet();
    final unapprovedIds = _retiredRe
        .allMatches(retired)
        .map((m) => m.group(1)!)
        .toSet();
    expect(insertedIds.intersection(unapprovedIds), isEmpty);
  });

  test('applied.md iki göçü de bekleyen olarak kaydediyor', () {
    final applied = File('supabase/applied.md').readAsStringSync();
    for (final name in [...syncFiles.keys, ...updateFiles.keys]) {
      expect(applied, contains(name), reason: '$name applied.md\'de yok');
    }
    expect(applied, contains('Görselli'));
    expect(applied, contains('2026-10-01_retired_local_unapprove.sql'));
  });

  test('yerelde kategorisi değişen ekleme satırlarının düzeltme göçü var', () {
    final fix = File(
      'supabase/2026-10-02_e2e_content_fixes.sql',
    ).readAsStringSync();
    for (final localId in _recategorisedLocally.keys) {
      final id = _uuid5('zankurd-local:$localId');
      expect(fix, contains(id), reason: '$localId için göç yok');
      expect(
        byId[localId]!.category,
        isNot(_recategorisedLocally[localId]),
        reason: '$localId yerelde hâlâ eski kategoride; listeden çıkar',
      );
    }
    // Koordinat sorusu: göçteki yeni şık yereldekiyle aynı.
    expect(fix, contains('Dem û lez'));
    expect(
      byId['ds_cografya_0177']!.answers,
      contains('Dem û lez'),
      reason: 'göç ile yerel şık ayrışmış',
    );
    expect(fix, contains(_uuid5('zankurd-local:ds_cografya_0177')));
  });
}
