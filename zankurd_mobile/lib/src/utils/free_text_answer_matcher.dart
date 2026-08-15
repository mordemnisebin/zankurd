/// Serbest metinli quiz yanıtını yalnız karşılaştırma için normalleştirir.
///
/// Kanonik Kurmancî yazım ekranda ve içerik bankasında korunur. Birleşik ve
/// ayrık Unicode yazımları eşitlenir; fakat `şêr` ile `ser` gibi farklı
/// sözcükleri birleştirmemek için Kurmancî harfler ASCII'ye katlanmaz.
/// Klavye kolaylığı gereken güvenli varyantlar soru bazında
/// `acceptedAnswers` içinde açıkça tanımlanır.
///
/// Türkçe cevapta `I/ı` ve `İ/i` eşlenir; küçük `i` hiçbir zaman `ı`ya
/// çevrilmez. Böylece `sik` ile `sık` farklı kalır.
String normalizeFreeTextAnswer(String value, {bool isTurkish = false}) {
  final localeAwareValue = isTurkish
      ? value
            .replaceAll('I\u0307', 'i')
            .replaceAll('İ', 'i')
            .replaceAll('I', 'ı')
      : value;
  return localeAwareValue
      .trim()
      .toLowerCase()
      .replaceAll('i\u0302', 'î')
      .replaceAll('e\u0302', 'ê')
      .replaceAll('u\u0302', 'û')
      .replaceAll('s\u0327', 'ş')
      .replaceAll('c\u0327', 'ç')
      .replaceAll(RegExp(r'\s+'), ' ');
}
