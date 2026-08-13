import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/question_bank_loader.dart';
import 'package:zankurd_mobile/src/l10n/explanation_ku.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';

/// Soru metinlerinde TEK bir tırnak biçimi kullanıldığının bekçisi.
///
/// ## Karar
///
/// Vurgulanan sözcük ve alıntılar düz çift tırnakla (`"..."`) yazılır.
/// Guillemet (`«...»`) ve eğri tırnak (`“...”`) kullanılmaz.
///
/// Banka baştan böyle değildi: 2026-08-12'de dokuz çevrimdışı bankada 8486
/// guillemet çifti vardı, buna karşılık on iki alan (sıralama sorularının
/// ipuçları) zaten düz tırnak kullanıyordu. Yani iki biçim yan yana
/// yaşıyordu ve oyuncu aynı ekranda ikisini birden görebiliyordu.
///
/// Dönüşüm ölçülerek yapıldı: hiçbir alanda dengesiz guillemet yoktu (0) ve
/// hiçbir alan guillemet ile düz tırnağı birlikte kullanmıyordu (0), yani
/// iç içe tırnak belirsizliği doğmadı. Değişimden sonra her metin, tırnak
/// karakterleri çıkarıldığında dönüşümden öncekiyle bire bir aynıydı —
/// 6659 alanda sıfır ihlal.
///
/// Bu bekçi neden var: aynı bankada daha önce bir tipografi düzeltmesi
/// Türkçe kesme işaretlerini bozmuştu (`1932'de` → `1932«de`). Biçim
/// kararları sözle değil, ölçüyle korunur.
void main() {
  const forbidden = {'«', '»', '\u201C', '\u201D', '\u201E', '\u201F'};

  test('yüklenen hiçbir soruda guillemet ya da eğri tırnak yok', () {
    final offenders = <String>[];

    void check(String? text, QuizQuestion q, String field) {
      if (text == null) return;
      for (final mark in forbidden) {
        if (text.contains(mark)) {
          offenders.add('${q.id}.$field: «$mark» → ${text.trim()}');
          return;
        }
      }
    }

    for (final q in QuestionBankLoader.instance.allQuestions) {
      check(q.prompt, q, 'prompt');
      check(q.promptTr, q, 'promptTr');
      check(q.explanation, q, 'explanation');
      check(q.explanationKu, q, 'explanationKu');
      check(q.explanationTr, q, 'explanationTr');
      check(q.correctAnswer, q, 'correctAnswer');
      check(q.correctAnswerTr, q, 'correctAnswerTr');
      check(q.hintKu, q, 'hintKu');
      check(q.hintTr, q, 'hintTr');
      check(q.imageAltKu, q, 'imageAltKu');
      check(q.imageAltTr, q, 'imageAltTr');
      for (var i = 0; i < q.answers.length; i++) {
        check(q.answers[i], q, 'answers[$i]');
      }
      final answersTr = q.answersTr;
      if (answersTr != null) {
        for (var i = 0; i < answersTr.length; i++) {
          check(answersTr[i], q, 'answersTr[$i]');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'Bu metinler guillemet ya da eğri tırnak taşıyor. Vurgu ve alıntı '
          'düz çift tırnakla yazılır; iki biçim yan yana durursa oyuncu aynı '
          'ekranda ikisini birden görür:\n${offenders.take(20).join("\n")}',
    );
  });

  test('banka dosyalarının hiçbir yerinde kalıntı yok', () {
    // Yükleyici yalnız oyuncuya ulaşan alanları okur. Dosyalarda ise
    // `metadata.reviewNote` gibi iç alanlar da var; kural orada da geçerli
    // ki bir sonraki toplu düzenleme eski biçimi geri getirmesin.
    final offenders = <String>[];
    final dir = Directory('assets/data');
    for (final entity in dir.listSync()) {
      if (entity is! File || !entity.path.endsWith('.json')) continue;
      final raw = entity.readAsStringSync();
      for (final mark in forbidden) {
        if (raw.contains(mark)) {
          offenders.add('${entity.path}: «$mark»');
          break;
        }
      }
      // Dosyanın hâlâ geçerli JSON olduğunu da burada doğrula: dönüşüm
      // tırnak ekliyor ve kaçış hatası dosyayı sessizce bozardı.
      expect(
        () => jsonDecode(raw),
        returnsNormally,
        reason: '${entity.path} artık geçerli JSON değil.',
      );
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('alıntı için tek tırnak kullanılmıyor', () {
    // `'sözcük'ek` deseni bankada 74 yerde vardı ve ev biçimine aykırıydı.
    //
    // Desen kesme işaretinden AYRILABİLİR: alıntı tırnağının öncesi boşluk
    // ya da satır başıdır, kesme işaretinin öncesi ise harftir (`1932'de`).
    // Bu ayrım şart — daha önce bir tipografi düzeltmesi tam bu farkı
    // gözetmediği için Türkçe kesme işaretlerini bozmuştu. Dönüşümden sonra
    // bankada 1674 kesme işareti duruyor ve hiçbiri değişmedi.
    final quotedSingle = RegExp(r"(?:(?<=\s)|^)'[^'\s][^']{0,40}'");
    final offenders = <String>[];
    for (final q in QuestionBankLoader.instance.allQuestions) {
      final fields = <String>[
        q.prompt,
        q.promptTr ?? '',
        q.explanation,
        q.explanationKu ?? '',
        q.explanationTr ?? '',
        ...q.answers,
        ...?q.answersTr,
      ];
      for (final field in fields) {
        if (quotedSingle.hasMatch(field)) {
          offenders.add('${q.id}: $field');
          break;
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'Alıntı ve vurgu düz ÇİFT tırnakla yazılır; tek tırnak yalnız '
          'kesme işaretidir:\n${offenders.take(15).join("\n")}',
    );
  });

  test('açıklama motoru da yeni biçimi üretiyor', () {
    // `explanationToKu` çıktısını bir zamanlar `«»`ye çeviriyordu. Banka
    // düz tırnağa geçtikten sonra bu, sessiz bir gerileme kaynağıydı:
    // metin dosyada düz tırnaklı, EKRANDA guillemet'li olurdu — yani banka
    // temizlense bile eski işaret çalışma anında geri gelirdi.
    for (final input in const [
      '"ateş" kelimesinin karşılığı "agir" olur.',
      "Doğru anlam: 'pir': 'çok'.",
    ]) {
      final output = explanationToKu(input);
      for (final mark in forbidden) {
        expect(
          output.contains(mark),
          isFalse,
          reason: 'Motor çıktısında «$mark» var: $output',
        );
      }
      expect(
        output.contains("'"),
        isFalse,
        reason: 'Motor çıktısında alıntı tek tırnağı kaldı: $output',
      );
    }
  });

  test('curated Dart bankası da aynı biçimde', () {
    final source = File(
      'lib/src/data/curated_question_bank.dart',
    ).readAsStringSync();
    for (final mark in forbidden) {
      expect(
        source.contains(mark),
        isFalse,
        reason:
            'curated_question_bank.dart içinde «$mark» var; Dart bankası da '
            'aynı tırnak biçimini kullanmalı.',
      );
    }
  });
}
