/// Hesap silme gibi yıkıcı eylemlerde "onay sözcüğü" karşılaştırması.
///
/// ## Kusur
///
/// Onay kutusu `value.trim() == confirmWord` ile karşılaştırıyordu ve alan
/// `TextCapitalization.characters` ile açılıyordu. Türkçe klavye `i`yi
/// büyük yazınca `İ` üretir (`SİL`), oysa sözcük `SIL`di; Kurmancî sözcük
/// `JÊ BIBE` ise `Ê` ister ve çoğu klavyede o harf yoktur. Düğme hiç
/// açılmıyordu: Apple'ın zorunlu kıldığı uygulama içi hesap silme akışı
/// kullanıcı için ulaşılamazdı.
///
/// ## Niçin sessizdi
///
/// Testler alana tam `SIL` yazıyordu; gerçek klavyenin ürettiği karakter
/// hiç denenmiyordu. Hata yalnız Türkçe/Kürtçe klavyeli bir cihazda görünür.
///
/// ## Kural
///
/// Büyük/küçük harf ve aksan duyarsız, Türkçe bilinçli: `İ ı I i`→`i`,
/// `ê`→`e`, `î`→`i`, `û`→`u`, `ç`→`c`, `ş`→`s` (ğ, ö, ü de), birleşik
/// aksan imleri atılır, boşluklar tek boşluğa iner.
class ConfirmWord {
  const ConfirmWord._();

  static const _fold = <String, String>{
    'İ': 'i',
    'ı': 'i',
    'I': 'i',
    'Ê': 'e',
    'ê': 'e',
    'Î': 'i',
    'î': 'i',
    'Û': 'u',
    'û': 'u',
    'Ç': 'c',
    'ç': 'c',
    'Ş': 's',
    'ş': 's',
    'Ğ': 'g',
    'ğ': 'g',
    'Ö': 'o',
    'ö': 'o',
    'Ü': 'u',
    'ü': 'u',
  };

  /// Karşılaştırma için katlanmış biçim.
  static String normalize(String input) {
    final out = StringBuffer();
    for (final rune in input.runes) {
      // Birleşik aksan imleri (e + U+0302 gibi) harfin kendisine dokunmaz.
      if (rune >= 0x0300 && rune <= 0x036F) continue;
      final char = String.fromCharCode(rune);
      final folded = _fold[char];
      if (folded != null) {
        out.write(folded);
      } else if (rune >= 0x41 && rune <= 0x5A) {
        out.writeCharCode(rune + 0x20);
      } else {
        out.write(char);
      }
    }
    return out.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// [input], [word] ile yukarıdaki kurala göre aynı mı.
  static bool matches(String input, String word) {
    final target = normalize(word);
    return target.isNotEmpty && normalize(input) == target;
  }
}
