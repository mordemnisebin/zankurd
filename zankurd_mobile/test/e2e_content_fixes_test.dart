// 2026-10-02 uçtan uca QA: dört yerel soru kusuru. Her bekçinin belgesi
// kusuru ve niçin sessiz kaldığını söyler.
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/question_bank_loader.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';

QuizQuestion _byId(String id) =>
    QuestionBankLoader.instance.allQuestions.firstWhere((q) => q.id == id);

void main() {
  // KUSUR: '"su" bi Kurmancî çi ye?' Cografya kategorisindeydi. Günün dersi
  // soruyu "Coğrafya" etiketiyle gösteriyordu; sorulan şey bir SÖZCÜK
  // ÇEVİRİSİ (Ziman). SESSİZ KALDI: kategori denetimleri yalnız kategorinin
  // geçerli olup olmadığına bakar, soru metninin konusuna bakmaz; soru
  // doğru çalışıyor, yalnız yanlış etiketle çıkıyordu.
  test('"su" çeviri sorusu Ziman kategorisindedir', () {
    expect(_byId('offline_0757').category, 'Ziman');
  });

  // KUSUR: "Kîjan koordînat...?" sorusunun cevabı "Hêlîpan û hêlîdirêj",
  // ama çeldirici "Dirêjahî û firehî" de enlem/boylam için kullanılan
  // geçerli bir Kurmancî ifadedir (dirêjahî = boylam, firehî = enlem): iki
  // doğru şık. SESSİZ KALDI: Türkçe karşılığı "Uzunluk ve genişlik"
  // (nesne ölçüsü) olduğundan çeviriden okuyan inceleme çeldiriciyi yanlış
  // sandı; Kurmancî okuyan ise "dirêjahî û firehî"nin ikinci anlamını
  // görebilirdi.
  test('koordinat sorusunda tek doğru şık vardır', () {
    final q = _byId('ds_cografya_0177');
    expect(q.correctAnswer, 'Hêlîpan û hêlîdirêj');
    expect(q.answers, isNot(contains('Dirêjahî û firehî')));
    expect(q.answers, hasLength(4));
    expect(q.answers.toSet(), hasLength(4));
  });

  // KUSUR: "xwendekar" görsel sorusunun çeldiricileri "bir", "ergatif",
  // "üç" idi: bir sayı, bir dilbilgisi terimi ve bir sayı; doğru cevap bir
  // isim ("öğrenci"). Şık türü ayrıştığı için cevap şıklara bakmadan
  // seçilebiliyordu. SESSİZ KALDI: şık dili/uzunluğu denetimleri türü
  // karşılaştırmaz; hepsi Türkçe ve kısaydı.
  test('xwendekar sorusunun çeldiricileri de isimdir', () {
    final q = _byId('offline_0110');
    expect(q.correctAnswer, 'öğrenci');
    for (final bad in const ['bir', 'ergatif', 'üç']) {
      expect(q.answers, isNot(contains(bad)));
    }
    expect(q.answers.toSet(), {'öğretmen', 'öğrenci', 'doktor', 'çiftçi'});
  });

  // KUSUR: "Doğru mu yanlış mı: "Mihemed Şêxo" terimi şu anlama gelir: ..."
  // Bir KİŞİ adı "terim" şablonuna konmuştu (Türkçe metinde). SESSİZ KALDI:
  // şablon 63 soruya kodlanmıştı; Kurmancî metin ("ew hunermend e") doğal,
  // yalnız Türkçe çeviri şablonu ayırt etmeden kişi adına da uygulamıştı.
  test('kişi adı soruları "terimi şu anlama gelir" şablonuyla çevrilmez', () {
    final persons = QuestionBankLoader.instance.allQuestions.where(
      (q) =>
          q.prompt.contains(' ew hunermend e ') ||
          q.prompt.contains(' ew muzîkjenê '),
    );
    expect(persons, isNotEmpty);
    for (final q in persons) {
      expect(
        q.promptTr ?? '',
        isNot(contains('terimi şu anlama gelir')),
        reason: '${q.id}: kişi bir "terim" değildir',
      );
    }
  });
}
