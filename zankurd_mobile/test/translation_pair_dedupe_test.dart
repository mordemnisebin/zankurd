import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/question_bank_assets.dart';
import 'package:zankurd_mobile/src/data/seen_question_store.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';

/// Aynı kelime çifti bir turda iki kez sorulmaz.
///
/// ## Kusur
///
/// Banka aynı çeviriyi iki yönde de soruyor:
///
///     Wêneya «hatin» tê çi wateyê?   → gelmek
///     Bi Kurmancî «gelmek» çi ye?    → hatin
///
/// İkisi ayrı sorudur, bu yüzden `_dedupeByPrompt` — birebir aynı metni
/// arayan tekilleştirme — ikisini de geçiriyordu. Ama aynı turda
/// çıktıklarında ikincisi bilgi ölçmez: cevabı birincisinin metninde
/// yazıyor.
///
/// Ölçüm (2026-08-01): tırnak içinde terim geçen 1330 çeviri sorusunda
/// 45 kelime çifti 2–5 ayrı soruda soruluyor. 10 soruluk bir turda
/// çakışma neredeyse kaçınılmazdı — canlı oda maçında "hatin/gelmek"
/// çifti arka arkaya çıktı ve ikincisi bedava puandı.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<QuizQuestion> bank;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SeenQuestionStore.resetInstance();
  });

  setUpAll(() {
    bank = [
      for (final asset in questionBankAssets)
        if (File(asset).existsSync())
          ...(jsonDecode(File(asset).readAsStringSync()) as List).map(
            (e) => QuizQuestion.fromJson(e as Map<String, dynamic>),
          ),
    ];
  });

  String? pairKey(QuizQuestion q) {
    final match = RegExp(
      '[«"“\']([^«»"”\']{2,40})[»"”\']',
    ).firstMatch(q.prompt);
    if (match == null) return null;
    final term = match.group(1)!.trim().toLowerCase();
    final answer = q.correctAnswer.trim().toLowerCase();
    if (term.isEmpty || answer.isEmpty || term == answer) return null;
    return ([term, answer]..sort()).join(' ');
  }

  test('bankada gerçekten ters çiftler var — bekçi kör değil', () {
    final counts = <String, int>{};
    for (final q in bank) {
      final key = pairKey(q);
      if (key != null) counts.update(key, (v) => v + 1, ifAbsent: () => 1);
    }
    final repeated = counts.values.where((c) => c > 1).length;
    expect(
      repeated,
      greaterThan(0),
      reason:
          'Kusur bankadan temizlendiyse bu bekçi anlamsızlaşır; o zaman '
          'seçimdeki koruma da gözden geçirilmeli.',
    );
  });

  test('seçilen turda hiçbir kelime çifti iki kez geçmiyor', () async {
    final store = await SeenQuestionStore.load();
    // Aynı havuzdan çok sayıda tur çek: rastgelelik tek denemede
    // çakışmayı gizleyebilir.
    for (var seed = 0; seed < 60; seed++) {
      final picked = store.preferUnseen(bank, 10, random: Random(seed));
      final seen = <String, String>{};
      for (final q in picked) {
        final key = pairKey(q);
        if (key == null) continue;
        expect(
          seen.containsKey(key),
          isFalse,
          reason:
              'seed=$seed turunda «$key» çifti iki kez soruldu:\n'
              '  ${seen[key]}\n  ${q.prompt}',
        );
        seen[key] = q.prompt;
      }
    }
  });

  test('çeviri olmayan sorular elenmiyor', () async {
    // Tarih, kültür ve dilbilgisi soruları tırnaklı terim taşımayabilir
    // ya da terim ile cevap aynı çifti kurmaz; koruma onlara dokunmamalı.
    final nonTranslation = bank.where((q) => pairKey(q) == null).length;
    expect(
      nonTranslation,
      greaterThan(100),
      reason: 'Bekçi kör kalmasın: kapsam dışı soru kümesi boş olmamalı.',
    );

    final store = await SeenQuestionStore.load();
    final pool = bank.where((q) => pairKey(q) == null).toList();
    final picked = store.preferUnseen(pool, 10, random: Random(7));
    expect(
      picked.length,
      10,
      reason: 'Kapsam dışı havuzdan tam sayıda soru gelmeli.',
    );
  });
}
