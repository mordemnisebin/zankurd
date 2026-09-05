/// Ünite başında gösterilebilen kısa, metin tabanlı rehber (SES YOK).
///
/// Yeni kelimeler, kısa bir dilbilgisi notu, iki örnek ve bir kültürel not
/// içerir. Kullanıcı istediğinde tekrar açabilir.
class GuidePair {
  const GuidePair(this.ku, this.tr);
  final String ku;
  final String tr;
}

class MiniGuide {
  const MiniGuide({
    required this.titleKu,
    required this.titleTr,
    required this.newWords,
    required this.grammarKu,
    required this.grammarTr,
    required this.examples,
    required this.cultureKu,
    required this.cultureTr,
  });

  final String titleKu;
  final String titleTr;
  final List<GuidePair> newWords;
  final String grammarKu;
  final String grammarTr;
  final List<GuidePair> examples;
  final String cultureKu;
  final String cultureTr;
}

/// Çayxane hikâyesine eşlik eden örnek mini rehber.
const MiniGuide cayxaneGuide = MiniGuide(
  titleKu: 'Li Çayxanê',
  titleTr: 'Çay Evinde',
  newWords: [
    GuidePair('çay', 'çay'),
    GuidePair('şekir', 'şeker'),
    GuidePair('xizmetkar', 'garson'),
    GuidePair('spas', 'teşekkür'),
  ],
  grammarKu:
      '"ji kerema xwe" hevokek e ku dilnizmiyê nîşan dide — mîna "lütfen".',
  grammarTr: '"ji kerema xwe" nezaket bildiren bir kalıptır — "lütfen" gibi.',
  examples: [
    GuidePair('Çayekê, ji kerema xwe.', 'Bir çay, lütfen.'),
    GuidePair('Spas, sax be.', 'Teşekkürler, sağ ol.'),
  ],
  cultureKu: 'Li gelek deveran, çayxane cihê hevaltî û sohbetê ye.',
  cultureTr: 'Birçok yerde çay evi, dostluğun ve sohbetin buluşma yeridir.',
);

const MiniGuide introducingYourselfGuide = MiniGuide(
  titleKu: 'Xwe Nasandin',
  titleTr: 'Kendini Tanıtma',
  newWords: [
    GuidePair('nav', 'ad'),
    GuidePair('xwendekar', 'öğrenci'),
    GuidePair('kêfxweş', 'memnun'),
  ],
  grammarKu: 'Ji bo xwe nasandinê tu dikarî bibêjî: "Navê min ... ye."',
  grammarTr: 'Kendini tanıtırken “Navê min ... ye” kalıbını kullanabilirsin.',
  examples: [
    GuidePair('Navê min Rojda ye.', 'Benim adım Rojda.'),
    GuidePair('Tu ji ku derê yî?', 'Nerelisin?'),
  ],
  cultureKu: 'Di nasînên nû de silav û pirsên kurt sohbetê hêsan dikin.',
  cultureTr: 'Yeni tanışmalarda selam ve kısa sorular sohbeti kolaylaştırır.',
);

const MiniGuide shoppingGuide = MiniGuide(
  titleKu: 'Li Dikanê',
  titleTr: 'Alışverişte',
  newWords: [
    GuidePair('dikan', 'dükkân'),
    GuidePair('bihâ', 'fiyat'),
    GuidePair('çend', 'ne kadar'),
    GuidePair('kîlo', 'kilo'),
  ],
  grammarKu: 'Ji bo bihayê pirsînê tu dikarî "Ev çend e?" bibêjî.',
  grammarTr: 'Fiyat sormak için “Ev çend e?” kalıbını kullanabilirsin.',
  examples: [
    GuidePair('Ev sêv çend in?', 'Bu elmalar ne kadar?'),
    GuidePair('Kîloyekê bidin min.', 'Bana bir kilo verin.'),
  ],
  cultureKu: 'Silav û spas danûstandinê germtir dikin.',
  cultureTr: 'Selam ve teşekkür alışveriş konuşmasını daha sıcak kılar.',
);

const MiniGuide askingDirectionsGuide = MiniGuide(
  titleKu: 'Rê Pirsîn',
  titleTr: 'Yol Sorma',
  newWords: [
    GuidePair('rê', 'yol'),
    GuidePair('rast', 'düz'),
    GuidePair('çep', 'sol'),
    GuidePair('li kêleka', 'yanında'),
  ],
  grammarKu: 'Ji bo cih pirsînê tu dikarî "... li ku ye?" bibêjî.',
  grammarTr: 'Bir yerin konumunu “... li ku ye?” diye sorabilirsin.',
  examples: [
    GuidePair('Pirtûkxane li ku ye?', 'Kütüphane nerede?'),
    GuidePair('Li çepê bizivire.', 'Sola dön.'),
  ],
  cultureKu: 'Destpêka bi "bibore" pirsê nermtir dike.',
  cultureTr: '“Bibore” ile başlamak yol sorusunu daha nazik kılar.',
);

const Map<String, MiniGuide> everydayGuides = {
  'cayxane': cayxaneGuide,
  'xwe-nasandin': introducingYourselfGuide,
  'kirin': shoppingGuide,
  'rê-pirsîn': askingDirectionsGuide,
};
