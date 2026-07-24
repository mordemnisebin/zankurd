import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'support/offline_bank_fixture.dart';

/// 2026-07-24 editoryal denetim.
///
/// Otomatik üretilmiş havuzda çeldiriciler başka soruların cevaplarından
/// rastgele çekilmişti. Sonuç: "Urartû navenda xwe li kîjan derê bû?"
/// sorusunun şıkları arasında "16. yüzyıl" ve "20. yüzyıl" duruyordu —
/// doğru cevap tür uyumsuzluğundan bakar bakmaz belli oluyordu.
///
/// 106 soru düzeltildi. Bu testler kusurun geri dönmesini engeller.
final _yearLike = RegExp(
  r'(\b\d{3,4}\b|yüzyıl|sedsal|y\.y\.|M\.Ö|b\.z\.)',
  caseSensitive: false,
);

bool _isYearLike(String value) => _yearLike.hasMatch(value);

/// Boş kalıp açıklamalar: soruyu açıklamak yerine kendini tekrar ederler.
final _hollowExplanation = RegExp(
  r"^(Ev ravekirin têgeha |Ev ravekirin bi )|"
  r"( di vê kategoriyê de têgeheke giring e\.$)|"
  r"( de bi vê ravekirinê tê bikaranîn\.$)",
);

/// Uygulamanın kendi veri şemasını soran "meta" sorular kullanıcıya
/// gösterilecek içerik değildir. 2026-07-24 denetiminde 16 tanesi
/// bulundu ve kaldırıldı (ör. "Di bankeke pirsan de qada 'etîket' ji bo
/// kîjan karê teknîkî ye?", "Wêneya bi etîketa 'govend' bi kîjan qadê re
/// têkildar e?"). Bu test yenilerinin sızmasını engeller.
final _appMeta = RegExp(
  r"(banke?ke? pirsan|banka pirsan|qada .etîket|Etîketa '.+' ya di wêneyê|"
  r"Wêneya bi etîketa)",
  caseSensitive: false,
);

void _metaGuardTests(List<QuizQuestion> Function() getBank) {
  test('soru bankası kendi şemasını sormaz', () {
    final offenders = getBank()
        .where((q) => _appMeta.hasMatch(q.prompt))
        .map((q) => '${q.id}: ${q.prompt}')
        .toList();

    expect(
      offenders,
      isEmpty,
      reason:
          'Uygulama/veri şeması hakkında soru eklendi: '
          '${offenders.take(3).join(" | ")}',
    );
  });
}

void main() {
  late List<QuizQuestion> offlineQuestionBank;

  setUpAll(() {
    offlineQuestionBank = loadOfflineBankFromJson();
  });

  _metaGuardTests(() => offlineQuestionBank);
  test('çeldiriciler doğru cevapla aynı türden olmalı (tarih/tarih-dışı)', () {
    final offenders = <String>[];
    for (final q in offlineQuestionBank) {
      if (q.type == QuestionType.trueFalse || q.answers.length < 4) continue;
      final correctIsYear = _isYearLike(q.correctAnswer);
      for (final answer in q.answers) {
        if (answer == q.correctAnswer) continue;
        if (_isYearLike(answer) != correctIsYear) {
          offenders.add('${q.id}: "$answer" ↔ "${q.correctAnswer}"');
          break;
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'Tür uyumsuz çeldirici eklendi (${offenders.length} soru). '
          'İlk örnekler: ${offenders.take(5).join(" | ")}',
    );
  });

  test('açıklamalar boş kalıp değil, gerçek bilgi taşır', () {
    // 960 boş kalıp açıklama terim↔tanım bilgisiyle değiştirildi.
    // Bu sayı yalnızca AZALMALIDIR.
    const baseline = 0;
    final hollow = offlineQuestionBank
        .where((q) => _hollowExplanation.hasMatch(q.explanation.trim()))
        .map((q) => q.id)
        .toList();

    expect(
      hollow.length,
      lessThanOrEqualTo(baseline),
      reason:
          'Kendini tekrar eden açıklama eklendi: '
          '${hollow.take(5).join(", ")}',
    );
  });

  test('her sorunun açıklaması cevabı gerçekten açıklayacak uzunlukta', () {
    // Sözlük soruları kısa açıklamayla yetinebilir; eşik düşük tutuldu.
    final tooShort = offlineQuestionBank
        .where((q) => q.explanation.trim().length < 12)
        .map((q) => q.id)
        .toList();

    expect(tooShort, isEmpty, reason: tooShort.take(10).join(', '));
  });
}
