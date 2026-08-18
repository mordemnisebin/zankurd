import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/question_bank_loader.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';

/// Türkçe çevirinin GERÇEKTEN çeviri olduğunun bekçisi.
///
/// ## Kusur
///
/// Türkçe kapsamı %16'dan %100'e çıkarıldı ve 29 parti hâlinde uygulandı.
/// Partilerin 11'i anlam açısından ayrı ayrı doğrulandı; kalan 18'i (008,
/// 010, 011, 013–028) doğrulanamadı — doğrulama ajanları aylık harcama
/// sınırına takıldı. O 18 parti yalnız MEKANİK kapıdan geçti: alan sayısı,
/// şık hizası, doğru cevabın şıklar içinde olması. Yani "Türkçe var mı"
/// sorusu soruldu, "Türkçe DOĞRU MU" sorusu sorulmadı.
///
/// Anlamı bir test kanıtlayamaz. Ama çevirinin yarım kaldığını ele veren
/// izler mekaniktir ve ölçülebilir:
///
///   * Türkçe metnin Kurmancî ile birebir aynı olması — hiç çevrilmemiş.
///   * Boş bir Türkçe alan — kırpılmış.
///   * Uzunluğun aşırı sapması — cümlenin bir bölümü düşmüş.
///   * Türkçe cümlede Kurmancî DİLBİLGİSİ sözcüğü — çeviri yarıda kalmış.
///
/// Son ölçüt bir istisna ister: dil öğreten sorular Kurmancî malzemeyi
/// tırnak içinde taşır ve taşımalıdır — «Ez dixwazim ku ez ...» cümlesini
/// Türkçeye çevirmek soruyu yok ederdi. Bu yüzden tırnak içi ayıklanır.
///
/// 2026-08-12'de bankanın tamamında ölçüldü: dört ölçütün dördü de sıfır.
/// Bu bekçi o sıfırı sabitler — bir sonraki parti sessizce yarım gelemez.
void main() {
  /// Kurmancî'nin işlev sözcükleri. Özel ad olamazlar; Türkçe bir cümlede
  /// tırnak dışında görünmeleri çevirinin bitmediğini gösterir.
  ///
  /// Türkçede de var olan biçimler (`ne`, `de`, `da`, `bi`) bilerek
  /// dışarıda: onları işaretlemek her Türkçe cümleyi şüpheli yapardı.
  ///
  /// Sınır `\b` ile YAZILAMAZ. Dart'ın `\b`'si ASCII tabanlıdır ve `ç`, `î`,
  /// `ş` gibi harfleri sözcük karakteri saymaz; `\bçi\b` deseni "geçişli"
  /// sözcüğünün ORTASINDA eşleşir, çünkü `e` ile `ç` arasında ASCII'ye göre
  /// bir sınır vardır. İlk taslak tam bu yüzden altı sahte isabet verdi
  /// (`geçişli`, `Herîrî`, `kuşlarla`…) ve aynı ölçüt Python'da sıfır
  /// veriyordu — Python'un `\b`'si Unicode farkındadır. Sınır burada elle,
  /// Unicode harf sınıfıyla kuruluyor.
  final kurmanjiFunctionWords = RegExp(
    r'(?<!\p{L})(çi|kîjan|çend|ku|hate|dibe|tê gotin|çawa|çima|heye|nîne'
    r'|herî)(?!\p{L})',
    caseSensitive: false,
    unicode: true,
  );

  /// Tırnak içi alıştırma malzemesi. Bankada dört tırnak biçimi de geçiyor.
  final quotedSpans = RegExp(
    '«[^»]*»|"[^"]*"|\u2018[^\u2019]*\u2019|\'[^\']*\'',
  );

  late List<QuizQuestion> translated;

  setUpAll(() {
    translated = QuestionBankLoader.instance.allQuestions
        .where((q) => (q.promptTr ?? '').trim().isNotEmpty)
        .toList();
  });

  test('Türkçe metin taşıyan soru sayısı ölçülen değerde', () {
    expect(
      translated.length,
      3085,
      reason:
          'Türkçe metin taşıyan soru sayısı değişti (yükleyicinin verdiği sayı). Yeni parti geldiyse bu '
          'sayı bilerek güncellenmeli; kendiliğinden düştüyse bir bankanın '
          'çevirisi kaybolmuş demektir.',
    );
  });

  test('hiçbir Türkçe soru Kurmancî metnin kopyası değil', () {
    final offenders = <String>[];
    for (final q in translated) {
      if (q.promptTr!.trim() == q.prompt.trim()) {
        offenders.add('${q.id}: promptTr, prompt ile birebir aynı');
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'Bu sorular çevrilmemiş ama çevrilmiş sayılıyor — TR oyuncu '
          'Kurmancî metin görür ve kapsam ölçüsü onu %100 sayar:\n'
          '${offenders.take(20).join("\n")}',
    );
  });

  test('hiçbir Türkçe şık boş değil', () {
    final offenders = <String>[];
    for (final q in translated) {
      final answersTr = q.answersTr;
      if (answersTr == null) continue;
      for (var i = 0; i < answersTr.length; i++) {
        if (answersTr[i].trim().isEmpty) {
          offenders.add('${q.id}: answersTr[$i] boş');
        }
      }
      final correctTr = q.correctAnswerTr;
      if (correctTr != null && correctTr.trim().isEmpty) {
        offenders.add('${q.id}: correctAnswerTr boş');
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'Boş bir şık, oyuncuya tıklanabilir ama okunamaz bir kutu '
          'gösterir:\n${offenders.take(20).join("\n")}',
    );
  });

  test('Türkçe metnin uzunluğu kaynaktan aşırı sapmıyor', () {
    // Sapma tek başına kusur değil — diller farklı uzunlukta yazar. Ama
    // yarıdan kısa bir çeviri, cümlenin bir bölümünün düştüğünü gösterir.
    final offenders = <String>[];
    for (final q in translated) {
      final source = q.prompt.trim();
      final target = q.promptTr!.trim();
      if (source.isEmpty) continue;
      final ratio = target.length / source.length;
      if (ratio < 0.55 || ratio > 1.9) {
        offenders.add(
          '${q.id}: oran ${ratio.toStringAsFixed(2)} '
          '(${source.length} → ${target.length})',
        );
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'Bu çevirilerin uzunluğu kaynaktan aşırı sapıyor; büyük olasılıkla '
          'bir bölümü düşmüş:\n${offenders.take(20).join("\n")}',
    );
  });

  test('Türkçe cümlede tırnak dışında Kurmancî dilbilgisi yok', () {
    final offenders = <String>[];
    for (final q in translated) {
      final withoutQuotes = q.promptTr!.replaceAll(quotedSpans, ' ');
      final match = kurmanjiFunctionWords.firstMatch(withoutQuotes);
      if (match != null) {
        offenders.add('${q.id}: «${match.group(0)}» — ${q.promptTr}');
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'Bu Türkçe sorularda tırnak DIŞINDA Kurmancî işlev sözcüğü var; '
          'çeviri yarıda kalmış görünüyor. Sözcük alıştırmanın kendisiyse '
          'tırnak içine alınmalı — hem bu bekçi susar hem de oyuncu neyin '
          'malzeme neyin soru olduğunu görür:\n${offenders.take(20).join("\n")}',
    );
  });
}
