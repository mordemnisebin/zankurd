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
