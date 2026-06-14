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
    (m) => 'Dîrok çand, abor, ziman, koç, çavkanî û jiyana rojane jî vedikole.',
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
];

/// Bilinen Türkçe şablonu Kurmancî'ye çevirir; eşleşme yoksa metni
/// olduğu gibi döndürür.
String explanationToKu(String explanation) {
  final text = explanation.trim();
  for (final rule in _rules) {
    final match = rule.pattern.firstMatch(text);
    if (match != null) return rule.build(match);
  }
  return explanation;
}
