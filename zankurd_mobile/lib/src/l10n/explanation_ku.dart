/// Offline soru bankasındaki açıklamalar tek dilli Türkçedir ve büyük
/// bölümü şablondan üretilmiştir. KU modunda bilinen şablonlar burada
/// Kurmancî'ye çevrilir; eşleşmeyen serbest metin Türkçe olarak kalır.
library;

class _Rule {
  const _Rule(this.pattern, this.build);

  final RegExp pattern;
  final String Function(Match match) build;
}

final List<_Rule> _rules = [
  // 'Kurmancî "biçûk" ≈ "küçük".'
  _Rule(
    RegExp(r'^Kurmancî "([^"]+)" ≈ "([^"]+)"\.$'),
    (m) => 'Kurmancî "${m[1]}" ≈ "${m[2]}".',
  ),
  // '"aile" kelimesinin karşılığı "malbat"dir.' — 20 sözlük açıklaması bu
  // kalıptaydı ve kural olmadığı için Kurmancî arayüzde Türkçe kalıyordu
  // (2026-07-26 denetimi).
  _Rule(
    RegExp(r'^"([^"]+)" kelimesinin karşılığı "([^"]+)"[\wıüö]*\.$'),
    (m) => 'Berambera peyva "${m[1]}" ev e: "${m[2]}".',
  ),
  // '"kevin" kelimesi "eski" demektir.'
  _Rule(
    RegExp(r'^"([^"]+)" kelimesi "([^"]+)" demektir\.$'),
    (m) => 'Peyva "${m[1]}" tê wateya "${m[2]}".',
  ),
  // 'Doğru yanıt: doğru.'
  _Rule(RegExp(r'^Doğru yanıt: ([^.]+)\.$'), (m) => 'Bersivên rast: ${m[1]}.'),
  // ''çîrok' Kurmancîde hikâye/anlatı anlamına gelir.'
  _Rule(
    RegExp(r"^'([^']+)' Kurmancîde ([^.]+) anlamına gelir\.$"),
    (m) => '\'${m[1]}\' bi Kurmancî tê wateya ${m[2]}.',
  ),
  // ''newal' Kurmancîde vadi anlamında kullanılır.'
  _Rule(
    RegExp(r"^'([^']+)' Kurmancîde ([^.]+) anlamında kullanılır\.$"),
    (m) => '\'${m[1]}\' bi Kurmancî di wateya ${m[2]} de tê bikaranîn.',
  ),
  // '"erê" evet, "na" hayır demektir.'
  _Rule(
    RegExp(r'^"([^"]+)" ([^,]+), "([^"]+)" ([^ ]+) demektir\.$'),
    (m) => '"${m[1]}" tê wateya ${m[2]}, "${m[3]}" jî tê wateya ${m[4]}.',
  ),
  // ''güzel/iyi' → xweş.'
  _Rule(
    RegExp(r"^'([^']+)' → ([^.]+)\.$"),
    // Ok işareti çıkarıldı: Rubik U+2192 taşımıyor, ok sistem yazı tipine
    // düşüyor ve cümlenin ortasında tip değişiyordu (2026-07-26).
    (m) => '\'${m[1]}\' tê wateya ${m[2]}.',
  ),
  // 'Görsel 'av' kavramını gösterir; doğru yanıt: su.'
  _Rule(
    RegExp(r"^Görsel '([^']+)' kavramını gösterir; doğru yanıt: ([^.]+)\.$"),
    (m) => 'Wêne têgeha "${m[1]}" nîşan dide; bersiva rast: ${m[2]}.',
  ),
  // 'Doğru anlam: "pirtûk" → "kitap".'
  _Rule(
    RegExp(r'^Doğru anlam: "([^"]+)" → "([^"]+)"\.$'),
    (m) => 'Wateya rast a "${m[1]}" ev e: "${m[2]}".',
  ),
  // 'Doğru eşleştirme: "teşekkür" → "spas".'
  _Rule(
    RegExp(r'^Doğru eşleştirme: "([^"]+)" → "([^"]+)"\.$'),
    (m) => 'Hevdûkirina rast: "${m[1]}" bi "${m[2]}" re ye.',
  ),
  // '"av" kelimesi "su" anlamına gelir.'
  _Rule(
    RegExp(r'^"([^"]+)" kelimesi "([^"]+)" anlamına gelir\.$'),
    (m) => 'Peyva "${m[1]}" tê wateya "${m[2]}".',
  ),
  // '"su" için doğru karşılık "av"tir.'
  _Rule(
    RegExp(r'^"([^"]+)" için doğru karşılık "([^"]+)"[\wıüö]*\.$'),
    (m) => 'Ji bo "${m[1]}" bersiva rast "${m[2]}" e.',
  ),
  // '"av" için doğru anlam "su"tir.'
  _Rule(
    RegExp(r'^"([^"]+)" için doğru anlam "([^"]+)"[\wıüö]*\.$'),
    (m) => 'Wateya rast a "${m[1]}" "${m[2]}" e.',
  ),
  // 'Görsel soru "av" kelimesini pekiştirir.'
  _Rule(
    RegExp(r'^Görsel soru "([^"]+)" kelimesini pekiştirir\.$'),
    (m) => 'Pirsa wêneyî peyva "${m[1]}" xurt dike.',
  ),
  // '"av" "su" demektir; "agir" ise "ateş" anlamına gelir.'
  _Rule(
    RegExp(
      r'^"([^"]+)" "([^"]+)" demektir; "([^"]+)" ise "([^"]+)" anlamına gelir\.$',
    ),
    (m) => '"${m[1]}" tê wateya "${m[2]}"; "${m[3]}" jî tê wateya "${m[4]}".',
  ),
  // '"çiya" coğrafya bağlamında "dağ" anlamına gelir.'
  _Rule(
    RegExp(r'^"([^"]+)" coğrafya bağlamında "([^"]+)" anlamına gelir\.$'),
    (m) => '"${m[1]}" di warê erdnîgariyê de tê wateya "${m[2]}".',
  ),
  // 'Doğru kavram "X"tir.' (tek veya çift tırnaklı)
  _Rule(
    RegExp(r'''^Doğru kavram ["']([^"']+)["'][\wıüö]*\.$'''),
    (m) => 'Têgeha rast "${m[1]}" e.',
  ),
  _Rule(
    RegExp(r'^Dengbêjlik ezgili sözlü anlatım geleneğidir\.$'),
    (m) => 'Dengbêjî kevneşopiyeke vegotina devkî ya bi awaz e.',
  ),
  // 'X için doğru kelime "Y"dir.' (tek veya çift tırnaklı)
  _Rule(
    RegExp(r'''^(.+) için doğru kelime ["']([^"']+)["'][\wıüö]*\.$'''),
    (m) => 'Ji bo ${m[1]} peyva rast "${m[2]}" e.',
  ),
  _Rule(
    RegExp(r'^Bu başlıklar coğrafyanın temel konularındandır\.$'),
    (m) => 'Ev sernav ji mijarên bingehîn ên erdnîgariyê ne.',
  ),
  _Rule(
    RegExp(r'^Coğrafya doğal ve beşeri çevreyi inceler\.$'),
    (m) => 'Erdnîgarî hawirdora xwezayî û mirovî vedikole.',
  ),
  _Rule(
    RegExp(r'^(.+) edebi metinleri anlamada kullanılan bir kavramdır\.$'),
    (m) => '${m[1]} têgehek e ku ji bo têgihîştina metnên edebî tê bikaranîn.',
  ),
  _Rule(
    RegExp(r'^(.+) coğrafi bir kavram olarak kullanılabilir\.$'),
    (m) => '${m[1]} wek têgeheke erdnîgarî tê bikaranîn.',
  ),
  _Rule(
    RegExp(r'^(.+) müzik kültüründe kullanılan bir kavramdır\.$'),
    (m) => '${m[1]} têgehek e ku di çanda muzîkê de tê bikaranîn.',
  ),
  _Rule(
    RegExp(r'^(.+) Kürt edebiyatı kategorisinde değerlendirilir\.$'),
    (m) => '${m[1]} di kategoriya edebiyata Kurdî de tê nirxandin.',
  ),
  _Rule(
    RegExp(r'^(.+) Kürt müziği kategorisinde ele alınır\.$'),
    (m) => '${m[1]} di kategoriya muzîka Kurdî de tê nirxandin.',
  ),
  _Rule(
    RegExp(r'^(.+) Kürt kültürü kategorisinde ele alınır\.$'),
    (m) => '${m[1]} di kategoriya çanda Kurdî de tê nirxandin.',
  ),
  _Rule(
    RegExp(r'^(.+) teknik ölçüden çok kültürel bir başlıktır\.$'),
    (m) => '${m[1]} ji pîvana teknîkî bêtir sernavek çandî ye.',
  ),
  _Rule(
    RegExp(r'^(.+), Kürt kültürü ve toplumsal hafıza içinde anlam kazanır\.$'),
    (m) => '${m[1]} di nav çanda Kurdî û bîra civakî de wate digire.',
  ),
  _Rule(
    RegExp(r'^(.+) tarihsel düşünme için yararlı bir kavramdır\.$'),
    (m) => '${m[1]} ji bo ramana dîrokî têgeheke kêrhatî ye.',
  ),
  _Rule(
    RegExp(
      r'^(.+) Kürt ve Kürdistan tarihi kategorisindeki kavramlardan biridir\.$',
    ),
    (m) => '${m[1]} yek ji têgehên kategoriya dîroka Kurd û Kurdistanê ye.',
  ),
  _Rule(
    RegExp(r'^(.+), Kürt kültüründe (.+) bağlamında değerlendirilir\.$'),
    (m) => '${m[1]} di çanda Kurdî de di çarçoveya "${m[2]}" de tê nirxandin.',
  ),
  _Rule(
    RegExp(r'^(.+), Kürt kültüründe (.+) alanıyla bağlantılıdır\.$'),
    (m) => '${m[1]} di çanda Kurdî de bi warê "${m[2]}" ve girêdayî ye.',
  ),
  _Rule(
    RegExp(
      r'^(.+), Kürt ve Kürdistan tarihi araştırmalarında (.+) olarak kullanılabilir\.$',
    ),
    (m) =>
        '${m[1]} di lêkolînên dîroka Kurd û Kurdistanê de wek "${m[2]}" tê bikaranîn.',
  ),
  _Rule(RegExp(r'^Doğru açıklama: (.+)\.$'), (m) => 'Şiroveya rast: ${m[1]}.'),
  _Rule(
    RegExp(
      r'^Tarih; kültür, ekonomi, dil, göç, kaynak ve gündelik yaşamı da inceler\.$',
    ),
    (m) =>
        'Dîrok çand, aborî, ziman, koç, çavkanî û jiyana rojane jî vedikole.',
  ),
  _Rule(
    RegExp(r'^(.+), Kürt edebiyatı alanında (.+) anlamında kullanılır\.$'),
    (m) =>
        '${m[1]} di warê edebiyata Kurdî de bi wateya "${m[2]}" tê bikaranîn.',
  ),
  _Rule(
    RegExp(r'^(.+), Kürt müziği alanında (.+) ile ilişkilidir\.$'),
    (m) => '${m[1]} di warê muzîka Kurdî de bi "${m[2]}" ve têkildar e.',
  ),
  _Rule(
    RegExp(r'^Mem û Zîn, Ehmedê Xanî ile özdeşleşmiş klasik bir eserdir\.$'),
    (m) => 'Mem û Zîn berhemeke klasîk e ku bi Ehmedê Xanî re tê naskirin.',
  ),
  _Rule(
    RegExp(r'^Seçilen isim Kürt edebiyatı bağlamında bilinen isimlerdendir\.$'),
    (m) => 'Navê hilbijartî di warê edebiyata Kurdî de navekî naskirî ye.',
  ),
  // '"bav" baba demektir.' — tek cümlelik basit tanımlar
  _Rule(
    RegExp(r'^"([^"]+)" ([^";:]+) demektir\.$'),
    (m) => 'Peyva "${m[1]}" tê wateya "${m[2]}".',
  ),
  // '"av" "su" demektir.' — her iki taraf tırnaklı; şablon-veri yerine
  // geçen kelime-anlamı üretiminde kullanılır.
  _Rule(
    RegExp(r'^"([^"]+)" "([^"]+)" demektir\.$'),
    (m) => 'Peyva "${m[1]}" tê wateya "${m[2]}".',
  ),
  // '"mase" kelimesi "sandalye" anlamına gelmez.' — yanlış eşleştirme
  // (trueFalse Şaş) açıklaması; şablon-veri yerine geçen üretim.
  _Rule(
    RegExp(r'^"([^"]+)" kelimesi "([^"]+)" anlamına gelmez\.$'),
    (m) => 'Peyva "${m[1]}" nayê wateya "${m[2]}".',
  ),
];

/// Bilinen Türkçe şablonu Kurmancî'ye çevirir; eşleşme yoksa metni
/// genel bir Kurmancî çerçeveyle döndürür (içerik çevrilemediğinde
/// ham Türkçe kalıbı doğrudan göstermemek için).
/// Kural motoruna giren metinde alıntı işaretlerini tekleştirir.
///
/// Aşağıdaki 45 kuralın hepsi `"` ya da `'` üzerine çapalı. Banka
/// 2026-07-30'da «guillemet» kuralında birleştirilince (üç ayrı tırnak
/// biçimi yan yana duruyordu) kuralların hiçbiri eşleşmez oldu ve 82
/// açıklama çevrilmeden, Türkçe hâliyle Kurmancî tura düştü.
///
/// Kuralları tek tek tırnağa duyarsız yazmak yerine giriş burada
/// normalleştirilir: motor tek biçim görür, çıktı ürünün biçimine döner.
/// Yeni kural yazan kişi tırnak biçimini düşünmek zorunda kalmaz.
String _withQuote(String text, String mark) =>
    text.replaceAll('«', mark).replaceAll('»', mark).replaceAll('"', mark);

/// Çıktıyı ürünün tırnak biçimine çevirir: düz ÇİFT tırnak.
///
/// Bu işlev bir zamanlar `«»` üretiyordu — açılış/kapanış ayrımı için
/// tırnakları sayıyordu. Ürünün biçimi 2026-08-12'de düz çift tırnağa
/// geçince o dönüşüm bir GERİLEME kaynağı oldu: banka tümüyle çevrilmiş
/// olsa bile motor, ürettiği her açıklamaya guillemet'i geri koyuyordu.
/// Yani metin dosyada düz tırnaklı, ekranda guillemet'li olurdu.
///
/// Açılış/kapanış ayrımı artık gereksiz: iki uç da aynı karakter.
String _productQuotes(String text) => text.replaceAll(RegExp("['«»]"), '"');

String explanationToKu(String explanation) {
  final text = explanation.trim();
  // Kurallar iki yerde kaynak biçimine çapalı ve ikisi de banka
  // düzenlenince kayıyor. Motor bu yüzden girişi **normalleştirmez**,
  // her kuralı birkaç varyantta dener; kural sırası korunur.
  //
  // Tırnak: kurallar tarihsel olarak hem `"…"` hem `'…'` ile yazılmış.
  // Banka 2026-07-30'da «» kuralında birleşince ikisi de eşleşmez oldu.
  //
  // Ayırıcı: bazı kurallar `"X" → Y.` biçimini bekliyor. Rubik U+2192
  // taşımadığı için ok metinden çıkarılıp `:` kondu (cümlenin ortasında
  // yazı tipi değişiyordu); o değişiklik de aynı kuralları düşürdü.
  // Hangi iki noktanın ayırıcı olduğu metne göre değişir: `«goşt»: Et.`
  // içinde tek aday var, `Doğru anlam: «pir»: «çok».` içinde ikinci olan
  // doğrudur. Tahmin etmek yerine her konum ayrı varyant olur; yanlış
  // varyant hiçbir kurala uymaz, yalnız doğru olan tutar.
  final separators = RegExp(r'(?<=\S):\s+').allMatches(text).toList();
  // Ok karakteri kaynağa düz yazılmaz, kod noktasından üretilir. Burada
  // yalnız **eşleştirme** için var: kuralların çıktısında yer almaz, ekrana
  // çıkmaz. `ui_glyph_coverage_test` dizge sabitlerinde bu karakteri haklı
  // olarak yasaklıyor (Rubik U+2192 taşımıyor); niyetin görünür olması için
  // kaçış değil, adı konmuş bir kod noktası kullanılır.
  final ruleSeparator = ' ${String.fromCharCode(0x2192)} ';
  final withArrow = [
    for (final match in separators)
      text.replaceRange(match.start, match.end, ruleSeparator),
  ];
  final variants = <String>[
    for (final quote in ['"', "'"]) ...[
      _withQuote(text, quote),
      for (final candidate in withArrow) _withQuote(candidate, quote),
    ],
  ];
  for (final rule in _rules) {
    for (final variant in variants) {
      final match = rule.pattern.firstMatch(variant);
      if (match != null) return _productQuotes(rule.build(match));
    }
  }
  return _productQuotes('Şirove: $text');
}
