import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/question_bank_assets.dart';
import 'package:zankurd_mobile/src/data/question_bank_loader.dart';

/// DeepSeek bankası olgusal hata oranı yüzünden oyuncuya yüklenmez.
///
/// Dosya inceleme için durabilir; runtime listesine dönmesi bu bekçiyi
/// kırar.
void main() {
  const quarantined = 'assets/data/deepseek_2026_08_18_questions.json';
  const verified = 'assets/data/deepseek_verified_2026_09_30_questions.json';

  test('DeepSeek bankası runtime listesinde yok', () {
    expect(questionBankAssets, isNot(contains(quarantined)));
  });

  test('yükleyici DeepSeek kayıtlarını oyuncuya vermez', () {
    final file = File(quarantined);
    expect(file.existsSync(), isTrue, reason: 'karantina dosyayı silmez');
    final ids = (jsonDecode(file.readAsStringSync()) as List)
        .cast<Map<String, dynamic>>()
        .map((row) => row['id'] as String)
        .toSet();
    expect(ids, isNotEmpty);

    // 2026-09-30: çok modelli olgu + Kurmancî denetiminden geçen kayıtlar
    // künyeli KOPYA olarak `deepseek_verified_2026_09_30_questions.json`a
    // alındı (aynı id'lerle). Karantinanın işi, doğrulanMAMIŞ kayıtları
    // tutmaktır: yüklenen her DeepSeek id'si kopya dosyada bulunmalı.
    final verifiedIds = (jsonDecode(File(verified).readAsStringSync()) as List)
        .cast<Map<String, dynamic>>()
        .map((row) => row['id'] as String)
        .toSet();
    expect(verifiedIds.length, greaterThan(400));
    final loadedIds = QuestionBankLoader.instance.allQuestions
        .map((q) => q.id)
        .toSet();
    expect(
      loadedIds.intersection(ids).difference(verifiedIds),
      isEmpty,
      reason: 'Doğrulanmamış karantina kayıtları hâlâ yükleniyor.',
    );
  });
}
