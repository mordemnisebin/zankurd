/// Büyük sayıların ekranda tek biçimle yazımı.
///
/// Türkçe de Kurmancî de binlik ayracı olarak nokta kullanır (`1.119`,
/// `12.400`); ondalık virgüldür. Yalnız tam sayılar biçimlenir. Dört
/// basamaktan kısa değerler (`999`) olduğu gibi kalır.
///
/// Ekranda bir sayacı `'$n'` ile yazmak 1000'e varana dek doğru görünür ve
/// o noktadan sonra okunması zorlaşır ("1119 kelime", "340/1000"); biçimi
/// tek yerde tutmak, ileride dil başına ayrım gerekirse tek noktadan
/// değiştirmeyi sağlar.
String groupThousands(int value) {
  final digits = value.abs().toString();
  if (digits.length <= 3) return value.toString();
  final out = StringBuffer(value < 0 ? '-' : '');
  final lead = digits.length % 3;
  if (lead > 0) out.write(digits.substring(0, lead));
  for (var i = lead; i < digits.length; i += 3) {
    if (out.length > (value < 0 ? 1 : 0)) out.write('.');
    out.write(digits.substring(i, i + 3));
  }
  return out.toString();
}
