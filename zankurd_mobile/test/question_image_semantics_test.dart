import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/question_bank_assets.dart';
import 'package:zankurd_mobile/src/l10n/strings.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';

/// Görselli sorular ekran okuyucuya sessiz kalmamalı.
///
/// ## Kusur
///
/// 2026-08-07 denetimi: 126 görselli sorunun hiçbirinde alt metin yoktu ve
/// `_QuestionImage` hiçbir `Semantics` sarmalı taşımıyordu. TalkBack ya da
/// VoiceOver kullanan bir oyuncu için görsel **hiç yoktu**.
///
/// Bunun ağırlığı soruya göre değişir. Görselin süs olduğu sorularda eksiklik,
/// görselin sorunun KENDİSİ olduğu sorularda ise soruyu çözülemez yapan bir
/// engeldir — "görseldeki çalgı hangisidir?" sorusunda görseli duyamayan
/// oyuncu dört şık arasından tahmin etmekten başka bir şey yapamaz.
///
/// ## Niçin alt metin zorunlu değil
///
/// Uydurma bir betimleme, betimlemenin yokluğundan kötüdür: ekran okuyucu
/// kullanıcısı duyduğu şeyin görselde olduğunu varsayar. Bu yüzden
/// `imageAltKu`/`imageAltTr` yalnız görseli gerçekten açıp bakan biri
/// tarafından yazılır ve boş kalabilir. Boş kaldığında arayüz
/// yerelleştirilmiş genel bir etiket kullanır ("Wêneya pirsê" / "Soru
/// görseli") — en azından bir görselin varlığı duyurulur.
///
/// Bu bekçi iki şeyi sabitler: her görselli soru bir etiket ÜRETEBİLİR
/// olmalı, ve yazılmış betimlemeler gerçekten betimleme olmalı (boş, tek
/// sözcük ya da dosya adı değil).
void main() {
  late List<QuizQuestion> visual;

  setUpAll(() {
    visual = [
      for (final asset in questionBankAssets)
        ...(jsonDecode(File(asset).readAsStringSync()) as List)
            .cast<Map<String, dynamic>>()
            .map(QuizQuestion.fromJson),
    ].where((q) => q.hasImage).toList();
  });

  test('görselli soru var ve her biri bir etiket üretebiliyor', () {
    expect(
      visual.length,
      greaterThan(100),
      reason: 'Görselli soru sayısı beklenmedik biçimde düştü',
    );

    // Arayüzün kullandığı zincir: sorunun kendi betimlemesi, yoksa genel
    // etiket. Genel etiketin her iki dilde de var olduğu burada doğrulanır —
    // anahtar defterinden düşerse ekran okuyucu ham anahtarı okur.
    for (final isKu in [true, false]) {
      final generic = Tr.forKu(K.questionImage, isKu);
      expect(
        generic,
        isNot(K.questionImage),
        reason: 'Genel görsel etiketi çevrilmemiş (isKu=$isKu)',
      );
      expect(generic.trim(), isNotEmpty);
    }
  });

  test('yazılmış betimlemeler gerçekten betimleme', () {
    final offenders = <String>[];
    for (final q in visual) {
      for (final entry in {'ku': q.imageAltKu, 'tr': q.imageAltTr}.entries) {
        final alt = entry.value;
        if (alt == null) continue;
        final trimmed = alt.trim();
        if (trimmed.isEmpty) {
          offenders.add('${q.id} (${entry.key}): boş betimleme');
          continue;
        }
        if (trimmed.length < 20) {
          offenders.add('${q.id} (${entry.key}): çok kısa — «$trimmed»');
        }
        if (trimmed.contains('.webp') || trimmed.contains('asset://')) {
          offenders.add('${q.id} (${entry.key}): dosya adı betimleme değil');
        }
        // Soru metnini kopyalamak betimleme değildir: ekran okuyucu aynı
        // cümleyi iki kez okur ve görselde ne olduğu yine bilinmez.
        if (trimmed == q.prompt.trim() ||
            trimmed == (q.promptTr ?? '').trim()) {
          offenders.add('${q.id} (${entry.key}): soru metninin kopyası');
        }
      }
    }
    expect(offenders, isEmpty, reason: offenders.take(15).join('\n'));
  });

  test('betimlemesi olan soruda iki dil de betimleme alıyor', () {
    // `imageAltFor` bir dilde betimleme yoksa diğerine düşer: yanlış
    // aksanla okunan bir betimleme, hiç betimleme olmamasından iyidir.
    final described = visual.where(
      (q) => q.imageAltKu != null || q.imageAltTr != null,
    );
    expect(
      described,
      isNotEmpty,
      reason:
          'Hiçbir görselde betimleme yok — alan eklendi ama hiç doldurulmadı',
    );
    for (final q in described) {
      for (final isKu in [true, false]) {
        expect(
          q.imageAltFor(isKu: isKu),
          isNotNull,
          reason: '${q.id}: isKu=$isKu için betimleme çözülemedi',
        );
      }
    }
  });
}
