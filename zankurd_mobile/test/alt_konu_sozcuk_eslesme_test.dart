import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/config/subcategory_config.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';

/// Alt konu anahtar kelimeleri tam sözcük eşleşir (2026-10-15).
///
/// ## Kusur
///
/// Eşleşme ham alt dizeydi: `med` Amed, Ehmed, Mihemed ve "Runnymede"de de
/// geçtiği için "Dîroka Kevn"in 56 sorusunun yaklaşık yarısı Medlerle değil
/// bu adlarla oraya düşüyordu; `dem` "serdem"i ve "demsal"ı, `tor` "motor"u
/// "Dijital û Înternet"e çekiyordu.
///
/// ## Niçin sessiz kaldı
///
/// Sonuç hep geçerli bir alt kategoriydi, hiçbir şey patlamadı; mevcut
/// testler yalnız "kart en az 20 soru taşıyor" diye bakıyordu ve yanlış
/// sorular o sayıyı şişirerek kartı görünür kılıyordu.
///
/// ## Bekçi
///
/// Adlar ve başka sözcüklerin içindeki hece alt konu belirlemez; gerçek
/// konu sözcüğü (çekimli de olsa) belirler.
QuizQuestion _q(String category, String prompt, [String answer = 'Cizîr']) =>
    QuizQuestion(
      id: 'q-${prompt.hashCode}',
      category: category,
      prompt: prompt,
      answers: [answer, 'x1', 'x2', 'x3'],
      correctAnswer: answer,
      explanation: 'Şîrove.',
    );

void main() {
  String sub(QuizQuestion q) => SubcategoryConfig.getSubcategoryId(q);

  test('Amed, Ehmed, Mihemed, Runnymede Dîroka Kevn\'e düşmez', () {
    for (final prompt in [
      'Bajarê Amedê di serdema Romayê de çi rolê digirt?',
      'Qadî Mihemed bi çi tê nasîn?',
      'Rast e an şaş e: Qral John Magna Carta li Runnymedeyê mor kir.',
      'Ehmedê Xanî di kîjan salê de ji dayik bû?',
    ]) {
      expect(sub(_q('Dîrok', prompt)), isNot('diroka_kevn'), reason: prompt);
    }
  });

  test('Med halk adı çekimli de olsa Dîroka Kevn\'e düşer', () {
    for (final prompt in [
      'Paytexta dewleta Medan kîjan bajar bû?',
      'Kîjan wek yek ji gelên antîk tê bibîranîn?',
      'Keyê dawî yê Medan kî bû?',
    ]) {
      expect(sub(_q('Dîrok', prompt)), 'diroka_kevn', reason: prompt);
    }
  });

  test(
    'dem yalnız kendi başına dilbilgisi sözcüğüdür; serdem/demsal değil',
    () {
      expect(sub(_q('Ziman', 'Kîjan demsal ya herî germ e?', 'Havîn')), '');
      expect(
        sub(_q('Ziman', 'Di vê hevokê de lêker kîjan demê ye?', 'Dema borî')),
        'reziman',
      );
    },
  );

  test('tor sözcüğü motor/transformator içinde bulunca eşleşmez', () {
    expect(
      sub(_q('Teknolojî', 'Motora elektrîkê enerjiyê çi dike?', 'Mekanîk')),
      isNot('dijital_internet'),
    );
    expect(
      sub(_q('Teknolojî', 'Di înternetê de tor çi ye?', 'Tora komputeran')),
      'dijital_internet',
    );
  });

  test(
    'uzun kök çekimli biçimi yakalar, noktalama taşıyan anahtar ham kalır',
    () {
      expect(
        sub(_q('Paradigma', 'Ronahiyê çawa belav dibe?', 'Bi pêl')),
        'zanist_jiyan',
      );
      expect(sub(_q('Çand', 'Dewrî; ew çi ye?', 'Mast')), 'tistonek');
    },
  );
}
