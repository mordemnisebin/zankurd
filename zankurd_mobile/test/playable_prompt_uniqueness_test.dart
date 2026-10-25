/// Oynanabilir havuzda normalleştirilmiş soru metni benzersiz olmalı.
///
/// ## Kusur (2026-10-25 içerik incelemesi)
///
/// Farklı banka dosyalarında aynı soru ikinci kez duruyordu:
/// `offline_curated_20304` ~ `kolay_dirok_08` ("Ehmedê Xanî kî bû?"),
/// `sf_nat_0005` ~ `bilim_0001` (Sîstema Rojê gerstêrk sayısı),
/// `wo-ku-001` ~ `dersler2_2026_10_08_0128` ("Ez diçim malê" sıralaması).
/// Oyuncu aynı soruyu iki kez görüyor, hatta iki farklı doğru cevap
/// metniyle karşılaşabiliyordu. Zayıf yarılar `retired_question_ids.dart`ta
/// emeklidir.
///
/// ## Niçin sessiz kalırdı
///
/// Kalite kapısı kanonik birebir kopyayı yakalar; kategori, doğru cevap ya
/// da açıklama farklı olunca kayıtlar "farklı" sayılır. Kimlikler ayrı
/// olduğu için yükleyici de iki kaydı ayrı tutar.
///
/// ## Neyi korur
///
/// Küçük harfe çevrilmiş, harf/rakam dışı her şey tek boşluğa indirilmiş
/// istem oynanabilir havuzda bir kez geçer. Aynı istemle gerçekten farklı
/// soru soran çiftler (şıklar ve doğru cevap tamamen farklı) yalnız
/// gerekçesiyle izin listesine girer.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/data/question_bank_loader.dart';

String _normalize(String prompt) => prompt
    .toLowerCase()
    .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ')
    .trim();

/// Aynı istemle farklı soru soran, bilerek tutulan çiftler.
const Map<String, String> _distinctSamePrompt = {
  // "Kîjan difire?": biri hayvanlar dersi (Eylo/kartal), öteki ulaşım dersi
  // (balafir/uçak); şıklar ve doğru cevap ortak değil.
  'kîjan difire': 'ders_2026_10_01_0051 ~ dersler3_2026_10_08_0088',
};

void main() {
  test('normalleştirilmiş soru metni oynanabilir havuzda benzersiz', () {
    expect(QuestionBankLoader.instance.allQuestions.length, greaterThan(1000));
    final playable = MockZanKurdRepository().playableQuestions;
    final groups = <String, List<String>>{};
    for (final q in playable) {
      groups.putIfAbsent(_normalize(q.prompt), () => []).add(q.id);
    }
    final duplicates = {
      for (final e in groups.entries)
        if (e.value.length > 1 && !_distinctSamePrompt.containsKey(e.key))
          e.key: e.value,
    };
    expect(
      duplicates,
      isEmpty,
      reason:
          'Aynı soru metni birden çok oynanabilir kayıtta: $duplicates. '
          'Zayıf yarıyı `retired_question_ids.dart`ta emekliye ayır ya da '
          'gerçekten farklı soruysa gerekçesiyle izin listesine ekle.',
    );
  });

  test('izin listesindeki çiftler hâlâ çift (bayat istisna kalmaz)', () {
    final playable = MockZanKurdRepository().playableQuestions;
    final counts = <String, int>{};
    for (final q in playable) {
      final key = _normalize(q.prompt);
      counts[key] = (counts[key] ?? 0) + 1;
    }
    for (final key in _distinctSamePrompt.keys) {
      expect(counts[key] ?? 0, greaterThan(1), reason: 'bayat istisna: $key');
    }
  });
}
