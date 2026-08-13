import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/question_bank_assets.dart';

/// Soru bankasında alıntı işaretinin bekçisi.
///
/// ## Kural (2026-08-12'de DEĞİŞTİ)
///
/// Alıntı ve vurgu **düz çift tırnakla** yapılır: `"agir"`. Guillemet
/// (`«»`) ve eğri tırnak (`“”`) bankaya giremez. Tek tırnak yalnız kesme
/// işaretidir — `1997'an`, `Şakiro'nun`, `Mem û Zîn'i`.
///
/// Kural bir zamanlar tersiydi: alıntı guillemet ile yapılır, düz tırnak
/// yasaktı. Uygulama sahibi 2026-08-12'de tek biçim olarak düz çift tırnağı
/// seçti ve banka tümüyle çevrildi: 8486 guillemet çifti, 3 eğri tırnak
/// çifti ve 74 `'sözcük'ek` kullanımı. Bu dosya o kararı izliyor.
///
/// ## Niçin bekçi
///
/// `tool/normalize_question_typography.py` 2026-07-30'da bankayı bir kez
/// tek kurala çekmişti (o gün 467 guillemet, 575 tek tırnak, 360 çift
/// tırnak yan yana duruyordu) ama bekçi yazılmamıştı ve aracın düzenli
/// ifadesinde bir boşluk vardı: Türkçede ek doğrudan kapanış tırnağına
/// yapışır —
///
///     "ateş" kelimesinin karşılığı "agir"dir.
///     Erebê Şemo, ... "Şivanê Kurmanca"yı (1935) yazdı.
///
/// — ve kapanıştan sonra harf gelince `(?![\w])` koşulu tutmuyordu. 27
/// kayıt böyle sızmıştı. O ders burada duruyor: kapanış tırnağının ardından
/// harf gelmesi kuraldışı DEĞİLDİR, olağandır.
///
/// İkinci ders: sınıf `\w` değil `\p{L}` olmalı. Dart'ta `\w` ASCII'dir ve
/// "Savaşı'nın ardından Kudüs'ü" dizisinde ilk kesmenin öncesindeki `ı`yı
/// harf saymaz; iki ayrı kesme işareti alıntı çifti sanılıyordu.
void main() {
  const banks = questionBankAssets;

  const fields = [
    'prompt',
    'promptTr',
    'explanation',
    'explanationKu',
    'explanationTr',
  ];

  /// Yasak alıntı biçimleri: guillemet ve eğri tırnak.
  final forbiddenQuotes = RegExp('[«»\u201C\u201D\u201E\u201F]');

  /// Alıntı olarak kullanılan TEK tırnak. Kesme işaretinden ayrımı açılış
  /// tarafındadır: alıntı harf/rakam OLMAYAN bir şeyden sonra açılır,
  /// kesme işaretinin öncesinde ise harf ya da rakam vardır.
  final singleQuoted = RegExp(
    r"(?<![\p{L}\p{N}])'[^'\n]{1,70}'",
    unicode: true,
  );

  test('alıntılar düz çift tırnak; guillemet ve eğri tırnak yok', () {
    final offenders = <String>[];

    for (final path in banks) {
      final file = File(path);
      expect(file.existsSync(), isTrue, reason: '$path bulunamadı');
      final rows = (jsonDecode(file.readAsStringSync()) as List)
          .cast<Map<String, dynamic>>();

      for (final row in rows) {
        void check(String? value, String where) {
          if (value == null || value.isEmpty) return;
          if (forbiddenQuotes.hasMatch(value) || singleQuoted.hasMatch(value)) {
            offenders.add('${row['id']}/$where: $value');
          }
        }

        for (final field in fields) {
          final value = row[field];
          if (value is String) check(value, field);
        }
        // Şıklar da oyuncuya gösterilir; kural orada da geçerli.
        for (final key in ['answers', 'answersTr']) {
          final list = row[key];
          if (list is List) {
            for (final answer in list) {
              if (answer is String) check(answer, key);
            }
          }
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          '${offenders.length} kayıtta eski alıntı biçimi var. Alıntı ve '
          'vurgu düz çift tırnakla yazılır:\n${offenders.take(8).join("\n")}',
    );
  });

  test('kesme işareti dokunulmadan kalır', () {
    // Bekçinin kendisi de sınanmalı: kural tek tırnak çiftini yasaklarken
    // kesme işaretini yasaklarsa banka Kurmancî ve Türkçe ek alamaz hâle
    // gelir. Bu üç yazım geçerlidir ve yakalanmamalıdır.
    for (final safe in [
      "Di sala 1997'an de Palmiya Zêrîn wergirt.",
      "Şakiro'nun sesi bir kuşaktır belleklerde.",
      "Ehmedê Xanî, Mem û Zîn'i 1692'de tamamladı.",
      // Yeni kuralın olağan hâli: kapanış tırnağına ek yapışır.
      '"ateş" kelimesinin karşılığı "agir"dir.',
      'Erebê Şemo "Şivanê Kurmanca"yı yazdı.',
    ]) {
      expect(
        forbiddenQuotes.hasMatch(safe) || singleQuoted.hasMatch(safe),
        isFalse,
        reason: 'Geçerli yazım kuraldışı sanıldı: $safe',
      );
    }

    // Buna karşılık eski biçimler — ek yapışsa bile — yakalanmalı.
    for (final bad in [
      '«ateş» kelimesinin karşılığı "agir"dir.',
      "Têgeha 'dengbêj' çi ye?",
      'Peyva \u201Cstêrk\u201D çi ye?',
    ]) {
      expect(
        forbiddenQuotes.hasMatch(bad) || singleQuoted.hasMatch(bad),
        isTrue,
        reason: 'Eski alıntı biçimi kaçtı: $bad',
      );
    }
  });
}
