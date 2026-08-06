import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Soru bankasında alıntı işaretinin bekçisi.
///
/// Kural: alıntı yalnız «guillemet» ile yapılır. Düz tırnak (' ") yalnız
/// kesme işareti olarak serbesttir — "1997'an", "Şakiro'nun", "Mem û Zîn'i".
///
/// `tool/normalize_question_typography.py` 2026-07-30'da bankayı tek kurala
/// çekmişti (aynı bankada 467 «guillemet», 575 tek tırnak, 360 çift tırnak
/// yan yana duruyordu). Ama bekçi yazılmamıştı ve aracın kendi düzenli
/// ifadesinde bir boşluk vardı: Türkçede ek doğrudan kapanış tırnağına
/// yapışır —
///
///     «ateş» kelimesinin karşılığı "agir"dir.
///     Erebê Şemo, ... "Şivanê Kurmanca"yı (1935) yazdı.
///
/// — ve kapanıştan sonra harf gelince `(?![\w])` koşulu tutmuyordu. 27 kayıt
/// böyle sızdı. Aynı 27 kayıt ikinci bir kusur daha taşıyordu: ek uyumu
/// bozuktu ("rast"dir → doğrusu "rast"tır, "toprak"dir → "toprak"tır).
/// Türkçesi kusursuz olması gereken bir üründe bu, tırnak karışıklığından
/// daha görünür bir hatadır.
///
/// Bu test iki kuralı birden sabitler: alıntı «guillemet»tir ve düz tırnak
/// çifti bankaya giremez. Kesme işareti dokunulmadan geçer.
void main() {
  const banks = [
    'assets/data/offline_questions.json',
    'assets/data/editorial_questions.json',
    'assets/data/community_questions.json',
    'assets/data/sentence_building_questions.json',
    'assets/data/expansion_2026_08_questions.json',
  ];

  const fields = [
    'prompt',
    'promptTr',
    'explanation',
    'explanationKu',
    'explanationTr',
  ];

  // Açılış: harf/rakam olmayan bir şeyden sonra. Kapanış: çift tırnakta
  // serbest (Türkçe `"` ile kesme yapmaz, yani çift tırnak çifti her zaman
  // alıntıdır), tek tırnakta harf/rakam gelmemeli.
  //
  // Sınıf `\w` DEĞİL `\p{L}`: Dart'ta `\w` ASCII'dir ve "Savaşı'nın
  // ardından Kudüs'ü" dizisinde ilk kesmenin öncesindeki `ı`yı harf
  // saymaz — iki ayrı kesme işareti alıntı çifti sanılıyordu. Python
  // aracının `\w`si unicode olduğu için aynı tuzağa düşmüyor.
  final doubleQuoted = RegExp(
    r'(?<![\p{L}\p{N}])"[^"\n]{1,70}"',
    unicode: true,
  );
  final singleQuoted = RegExp(
    r"(?<![\p{L}\p{N}])'[^'\n]{1,70}'(?![\p{L}\p{N}])",
    unicode: true,
  );

  test('alıntılar «guillemet», düz tırnak çifti yok', () {
    final offenders = <String>[];

    for (final path in banks) {
      final file = File(path);
      expect(file.existsSync(), isTrue, reason: '$path bulunamadı');
      final rows = (jsonDecode(file.readAsStringSync()) as List)
          .cast<Map<String, dynamic>>();

      for (final row in rows) {
        for (final field in fields) {
          final value = row[field];
          if (value is! String || value.isEmpty) continue;
          if (doubleQuoted.hasMatch(value) || singleQuoted.hasMatch(value)) {
            offenders.add('${row['id']}/$field: $value');
          }
        }
        // Şıklar da oyuncuya gösterilir; kural orada da geçerli.
        final answers = row['answers'];
        if (answers is List) {
          for (final answer in answers) {
            if (answer is! String) continue;
            if (doubleQuoted.hasMatch(answer) ||
                singleQuoted.hasMatch(answer)) {
              offenders.add('${row['id']}/answers: $answer');
            }
          }
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          '${offenders.length} kayıtta düz tırnak çifti var; alıntı «» ile '
          'yapılır. Onarmak için: python3 '
          'tool/normalize_question_typography.py --apply\n'
          '${offenders.take(8).join("\n")}',
    );
  });

  test('kesme işareti dokunulmadan kalır', () {
    // Bekçinin kendisi de sınanmalı: kural düz tırnağı yasaklarken kesme
    // işaretini yasaklarsa banka Kurmancî ve Türkçe ek alamaz hâle gelir.
    // "1997'an de", "Şakiro'nun", "Mem û Zîn'i" geçerli yazımlardır.
    for (final safe in [
      "Di sala 1997'an de Palmiya Zêrîn wergirt.",
      "Şakiro'nun sesi bir kuşaktır belleklerde.",
      "Ehmedê Xanî, Mem û Zîn'i 1692'de tamamladı.",
    ]) {
      expect(
        doubleQuoted.hasMatch(safe) || singleQuoted.hasMatch(safe),
        isFalse,
        reason: 'Kesme işareti alıntı sanıldı: $safe',
      );
    }

    // Buna karşılık gerçek düz tırnak çifti — ek yapışsa bile — yakalanmalı.
    for (final bad in [
      '«ateş» kelimesinin karşılığı "agir"dir.',
      "Têgeha 'dengbêj' çi ye?",
      'Erebê Şemo "Şivanê Kurmanca"yı yazdı.',
    ]) {
      expect(
        doubleQuoted.hasMatch(bad) || singleQuoted.hasMatch(bad),
        isTrue,
        reason: 'Düz tırnak çifti kaçtı: $bad',
      );
    }
  });
}
