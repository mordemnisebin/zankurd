import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/question_bank_assets.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';

/// Banka büyüdükçe açılış maliyeti sessizce büyümesin.
///
/// ## Niçin ölçülüyor
///
/// `QuestionBankLoader.load()` uygulama açılışında bütün JSON bankalarını
/// okur ve `QuizQuestion.fromJson` ile ayrıştırır. Bu iş açılış yolunda
/// durur: ölçüm yapılmazsa her yeni banka açılışa birkaç milisaniye ekler
/// ve kimse tek tek fark etmez — 2026-08-06'da banka bir batch'te %12
/// büyüdü (1832 → 2050 kayıt).
///
/// Üretimde çözme arka isolate'te yapılır (`question_bank_loader.dart`),
/// yani bu süre doğrudan kare düşüşü değildir; yine de ilk soru ekranının
/// ne kadar beklediğini belirler.
///
/// ## Bu bekçi ne yapar, ne yapmaz
///
/// Kesin milisaniye iddiası taşımaz — koşucu makinesi değişir, sayı oynar.
/// Yaptığı şey bir TAVAN koymak: bugünkü ölçümün birkaç katı aşılırsa
/// birileri açılış yoluna ağır bir şey koymuştur. Eşik bilerek gevşektir;
/// amaç gürültü üretmek değil, sıçramayı yakalamak.
void main() {
  test('bütün bankalar açılış bütçesi içinde ayrıştırılıyor', () {
    var totalBytes = 0;
    var totalRecords = 0;
    final perBank =
        <String, ({int bytes, int records, int decodeUs, int mapUs})>{};

    for (final asset in questionBankAssets) {
      // Pakete giren gerçek boyut UTF-8 BAYT sayısıdır. `String.length`
      // UTF-16 kod birimi sayar ve Türkçe/Kurmancî diakritikleri yüzünden
      // dosya boyutunun altında kalır (342.685 vs 361.324) — uygulama
      // boyutu tartışılırken yanıltıcı olur.
      final file = File(asset);
      final raw = file.readAsStringSync();
      totalBytes += file.lengthSync();

      final decodeWatch = Stopwatch()..start();
      final decoded = jsonDecode(raw) as List;
      decodeWatch.stop();

      final mapWatch = Stopwatch()..start();
      final questions = decoded
          .map((e) => QuizQuestion.fromJson(e as Map<String, dynamic>))
          .toList(growable: false);
      mapWatch.stop();

      totalRecords += questions.length;
      perBank[asset.split('/').last] = (
        bytes: file.lengthSync(),
        records: questions.length,
        decodeUs: decodeWatch.elapsedMicroseconds,
        mapUs: mapWatch.elapsedMicroseconds,
      );
    }

    final decodeUs = perBank.values.fold<int>(0, (s, v) => s + v.decodeUs);
    final mapUs = perBank.values.fold<int>(0, (s, v) => s + v.mapUs);
    final totalMs = (decodeUs + mapUs) / 1000;

    // Ölçüm çıktısı: `flutter test --reporter expanded` ile okunur ve
    // büyüme eğilimi commit'ler arasında karşılaştırılabilir kalır.
    // ignore: avoid_print
    print(
      'question-bank-parse: banks=${questionBankAssets.length} '
      'records=$totalRecords bytes=$totalBytes '
      'decode=${(decodeUs / 1000).toStringAsFixed(1)}ms '
      'map=${(mapUs / 1000).toStringAsFixed(1)}ms '
      'total=${totalMs.toStringAsFixed(1)}ms',
    );
    for (final entry in perBank.entries) {
      // ignore: avoid_print
      print(
        '  ${entry.key}: ${entry.value.records} kayıt, '
        '${entry.value.bytes} bayt, '
        '${((entry.value.decodeUs + entry.value.mapUs) / 1000).toStringAsFixed(1)}ms',
      );
    }

    expect(
      totalMs,
      lessThan(1500),
      reason:
          'Bütün bankaların açılışta ayrıştırılması ${totalMs.toStringAsFixed(1)}ms '
          'sürdü. Tavan gevşek; aşıldıysa açılış yoluna ağır bir iş girmiş '
          'demektir (ölçüm: $perBank).',
    );
    expect(
      totalBytes,
      lessThan(8 * 1024 * 1024),
      reason:
          'Paketlenen banka JSON toplamı $totalBytes bayt. Uygulama boyutu '
          've açılış okuması buna doğrudan bağlı.',
    );
  });
}
