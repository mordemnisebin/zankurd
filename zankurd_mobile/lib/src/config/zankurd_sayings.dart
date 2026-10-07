/// ZanKurd günün sözü (atasözü) havuzu.
///
/// Tek doğruluk kaynağı — ders veya bildirim içerikleri buradan çeker.
/// İçerik takımı yeni atasözü eklemek için bu dosyayı günceller.
///
/// Biçim: (Kurmancî metin, Türkçe karşılığı)
typedef ZanKurdSaying = (String ku, String tr);

class ZanKurdSayings {
  const ZanKurdSayings._();

  static const List<ZanKurdSaying> pool = [
    ('Zanîn ronahî ye.', 'Bilgi ışıktır.'),
    ('Dilop bi dilop gol çêdibe.', 'Damla damla göl olur.'),
    ('Gotina rast şîrîn e.', 'Doğru söz tatlıdır.'),
    ('Yek gul biharê nayîne.', 'Bir çiçekle bahar gelmez.'),
    ('Ziman mifta dil e.', 'Dil, gönlün anahtarıdır.'),
    ('Aqil tacê zêrîn e.', 'Akıl altın taçtır.'),
    ('Hevaltî dewlemendiya dil e.', 'Dostluk gönlün zenginliğidir.'),
    ('Bêhna fireh mifta serkeftinê ye.', 'Sabır, başarının anahtarıdır.'),
    ('Her roj hînbûnek nû ye.', 'Her gün yeni bir öğrenmedir.'),
    ('Çirûskek dikare daristanê ronî bike.', 'Bir kıvılcım ormanı aydınlatır.'),
  ];
}
