import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/learner_lexicon.dart';

/// Sözlük Türkçe -> Kurmancî arama (2026-10-24).
///
/// ## Kusur
///
/// Sözlük yalnız Kurmancî sözcükten Türkçeye doğru kullanılabiliyordu. Türkçe
/// bir sözcüğün Kurmancîsini arayan (`kapı` -> `Derî`) terim, biçim ve anlamın
/// karıştığı tek sıralamayla karşılaşıyordu: anlamla eşleşen sonuçlar en sona
/// düşüyordu.
///
/// ## Niçin sessiz kalırdı
///
/// Arama her zaman BİR şey döndürür; sıranın ya da Türkçe harf katlamasının
/// bozulduğunu yalnız doğru sonucu bilen biri fark eder.
///
/// ## Kural
///
/// [LearnerLexicon.searchByMeaning] yalnız Türkçe anlamlarda arar; `İ/ı`,
/// `ş`, `ğ`, `ç`, `ö`, `ü` ve büyük/küçük harf yok sayılır. Tam anlam önce,
/// anlam parçasının başı sonra, sözcük başı sonra, içinde geçen en sonda.
void main() {
  List<String> terms(String query) => [
    for (final e in LearnerLexicon.searchByMeaning(query)) e.termKu,
  ];

  test('kapı -> Derî önce gelir', () {
    final found = terms('kapı');
    expect(found.first, 'Derî');
    // "Bu kapıdır" anlamlı cümle sonra gelir.
    expect(found, contains('Ev derî ye'));
    expect(found.indexOf('Ev derî ye'), greaterThan(0));
  });

  test('büyük/küçük harf ve noktalı-noktasız ı fark etmez', () {
    final expected = terms('kapı');
    expect(terms('KAPI'), expected);
    expect(terms('kapi'), expected);
    expect(terms('Kapı'), expected);
    expect(terms('  kapı  '), expected);
  });

  test('İ/ı katlaması: ışık -> Ronahî, ISIK ve isik de bulur', () {
    for (final query in ['ışık', 'IŞIK', 'isik', 'Işık']) {
      expect(terms(query), contains('Ronahî'), reason: query);
    }
    expect(terms('ışık').first, 'Ronahî');
  });

  test('Türkçe aksanlar: ş ğ ç ö ü aksansız yazımla da eşleşir', () {
    // Sözlükte Türkçe aksanlı anlamlar olan birkaç madde.
    final withAccent = [
      for (final e in LearnerLexicon.entries)
        if (RegExp('[şğçöüİı]').hasMatch(e.meaningTr)) e,
    ];
    expect(withAccent, isNotEmpty);
    for (final entry in withAccent.take(60)) {
      final word = entry.meaningTr
          .split(RegExp(r'[\s/,;()]+'))
          .firstWhere((w) => w.length >= 3, orElse: () => entry.meaningTr);
      final asciiWord = LearnerLexicon.foldForSearch(word);
      expect(
        LearnerLexicon.searchByMeaning(asciiWord).map((e) => e.id),
        contains(entry.id),
        reason: '"$asciiWord" -> ${entry.id} (${entry.meaningTr})',
      );
    }
  });

  test('Kurmancî terim Türkçe yönde aranmaz', () {
    // `Derî` yalnız Kurmancî terimdir; Türkçe anlamlarda geçmez.
    expect(terms('derî'), isNot(contains('Derî')));
  });

  test('anlam parçası ayraçlarla bölünür (/ , ;)', () {
    // "Günaydın / İyi günler": ikinci parçayla da bulunur ve tam eşleşir.
    final found = LearnerLexicon.searchByMeaning('iyi günler');
    expect(found.map((e) => e.id), contains('rojbas'));
  });

  test('boş sorgu bütün sözlüğü verir, eşleşmeyen sorgu boş döner', () {
    expect(
      LearnerLexicon.searchByMeaning('').length,
      LearnerLexicon.entries.length,
    );
    expect(LearnerLexicon.searchByMeaning('zzzqqqxxx'), isEmpty);
  });

  test('byId bilinen maddeyi bulur, bilinmeyeni null verir', () {
    expect(LearnerLexicon.byId('q-deri')?.termKu, 'Derî');
    expect(LearnerLexicon.byId('yok-boyle-bir-madde'), isNull);
  });
}
