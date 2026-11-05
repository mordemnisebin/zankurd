import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/fact_groups.dart';
import 'package:zankurd_mobile/src/data/question_bank_loader.dart';

import 'support/widget_test_helpers.dart';

/// Aynı olguyu soran soruların grup haritası (GPT-6 Pro alan 7, tekrarlar).
///
/// ## Kusur
///
/// Havuz küçük olduğundan aynı olgu birden çok kimlikle bankada durur
/// ("Mem û Zîn'in yazarı" yedi kimlik). Sahip hiçbirinin silinmesini
/// istemedi; ikinci ve sonraki kimlikler farklı bir olguyu soracak biçimde
/// yeniden yazıldı, harita da emniyet ağıdır.
///
/// ## Niçin sessiz kalıyordu
///
/// "Görüldü" geçmişi kimlik tabanlıdır: aynı olgunun öteki kimliği hiç
/// görülmemiş sayılır ve seçici onu aynı turda yine seçebilir; hiçbir test
/// bir turun içinde aynı olgunun iki kez çıkmadığına bakmıyordu.
///
/// ## Bekçi
///
/// Haritadaki her kimlik bankada vardır, her grupta en az iki üye bulunur,
/// anahtar grubun ilk üyesidir ve seçici (`loadQuestions`) bir turda aynı
/// gruptan en çok bir soru verir.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Map<String, dynamic> bank;

  setUpAll(() {
    bank = {for (final q in QuestionBankLoader.instance.allQuestions) q.id: q};
  });

  test('haritadaki her kimlik bankada var, her grup en az iki üyeli', () {
    final eksik = [
      for (final id in factGroupOf.keys)
        if (!bank.containsKey(id)) id,
    ];
    expect(eksik, isEmpty, reason: 'bankada olmayan kimlikler: $eksik');
    final gruplar = <String, List<String>>{};
    factGroupOf.forEach((id, g) => gruplar.putIfAbsent(g, () => []).add(id));
    for (final e in gruplar.entries) {
      expect(e.value.length, greaterThanOrEqualTo(2), reason: e.key);
      expect(
        factGroupOf[e.key],
        e.key,
        reason: '${e.key}: grup anahtarı grubun üyesi olmalı',
      );
    }
  });

  test('keepFirstPerGroup aynı gruptan yalnız ilk soruyu tutar', () {
    final pool = QuestionBankLoader.instance.allQuestions
        .where(
          (q) => const {
            'hat_0011',
            'hat_0018',
            'hat_0025',
            'hat_0001',
            'hat_0009',
          }.contains(q.id),
        )
        .toList();
    expect(pool.length, 5);
    final kept = FactGroups.keepFirstPerGroup(pool).map((q) => q.id).toList();
    expect(kept.length, 2, reason: '$kept');
    expect(kept.first, pool.first.id);
  });

  test('seçici bir turda aynı olgu grubundan en çok bir soru verir', () async {
    for (var i = 0; i < 60; i++) {
      SharedPreferences.setMockInitialValues({});
      final repo = freshMockRepository();
      for (final category in ['Edebiyat', 'Sînema', 'Dîrok', 'Cîhan']) {
        final turn = await repo.loadQuestions(categoryId: category, limit: 10);
        final groups = [for (final q in turn) ?FactGroups.of(q.id)];
        expect(
          groups.toSet().length,
          groups.length,
          reason: '$category turunda aynı olgu iki kez: $groups',
        );
      }
    }
  });

  test('seçici, aynı gruptan çok üyeli havuzda yalnız birini verir', () async {
    final uyeler = QuestionBankLoader.instance.allQuestions
        .where((q) => FactGroups.of(q.id) == 'edit_edebiyat_0001')
        .toList();
    expect(uyeler.length, greaterThanOrEqualTo(5));
    final digerleri = QuestionBankLoader.instance.allQuestions
        .where((q) => FactGroups.of(q.id) == null && q.category == 'Edebiyat')
        .take(8)
        .toList();
    expect(digerleri.length, 8);
    for (var i = 0; i < 30; i++) {
      SharedPreferences.setMockInitialValues({});
      final repo = freshMockRepository();
      final turn = await repo.selectFreshForTesting([
        ...uyeler,
        ...digerleri,
      ], 6);
      final sayi = turn.where((q) => FactGroups.of(q.id) != null).length;
      expect(
        sayi,
        lessThanOrEqualTo(1),
        reason: 'tur: ${turn.map((q) => q.id)}',
      );
    }
  });

  test(
    'seçici ve günlük havuz haritayı gerçekten kullanır (bağlantı bekçisi)',
    () {
      final kaynak = File(
        'lib/src/data/mock_zankurd_repository.dart',
      ).readAsStringSync();
      // _selectFresh adayları ve günlük/aynı-olgu süzgeci haritadan geçmeli;
      // biri silinirse tur içi tekrar sessizce geri gelir (rastgele turlar
      // çarpışmayı nadiren gösterdiği için başka test yakalamaz).
      expect(
        RegExp(r'FactGroups\.keepFirstPerGroup\(').allMatches(kaynak).length,
        greaterThanOrEqualTo(2),
      );
    },
  );

  test('yeniden yazılan yinelenen sorular yeni olguda ve eski kök gitmiş', () {
    final yazilan =
        (jsonDecode(
                  File(
                    'test/fact_group_yeniden_yazilanlar.json',
                  ).readAsStringSync(),
                )
                as List)
            .cast<Map<String, dynamic>>();
    expect(yazilan.length, greaterThan(30));
    for (final y in yazilan) {
      final q = bank[y['id']];
      expect(q, isNotNull, reason: '${y['id']} bankada yok');
      expect(q.prompt, y['prompt'], reason: '${y['id']} kök');
      expect(q.prompt, isNot(y['oldPrompt']), reason: '${y['id']} eski kök');
      expect(q.correctAnswer, y['correct'], reason: '${y['id']} doğru şık');
      expect(
        (q.answers as List).cast<String>().toList()..sort(),
        (y['answers'] as List).cast<String>(),
        reason: '${y['id']} şık kümesi',
      );
    }
  });
}
