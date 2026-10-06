import 'package:flutter/foundation.dart';

@immutable
class LearnerLexiconSource {
  const LearnerLexiconSource({
    required this.id,
    required this.titleKu,
    required this.titleTr,
    required this.categoryKu,
    required this.categoryTr,
  });

  final String id;
  final String titleKu;
  final String titleTr;
  final String categoryKu;
  final String categoryTr;
}

@immutable
class LearnerLexiconEntry {
  const LearnerLexiconEntry({
    required this.id,
    required this.termKu,
    required this.meaningTr,
    required this.sourceId,
    this.forms = const [],
  });

  final String id;
  final String termKu;
  final String meaningTr;
  final String sourceId;

  /// Terimin cümlede görünen öteki biçimleri (çekimli fiil, tamlama/yönelme
  /// biçimi, yazım değişkesi): `Mal` için `malê`, `Zanîn` için `dizanim`.
  /// Arama bu biçimleri de tarar; böylece öğrenen sorudaki çekimli sözcüğü
  /// aratınca madde başını bulur. Yeni bir biçim için ayrı kayıt AÇILMAZ.
  final List<String> forms;
}

/// Öğrenen sözlüğünün ilk, editoryal olarak izlenebilir yerel çekirdeği.
///
/// Buradaki çiftler yeni bir çeviri üretmez. Tamamı
/// [MockZanKurdRepository] içindeki mevcut, uygulama-yazarlı ders
/// slaytlarında açıkça bulunan Kurmancî → Türkçe çiftlerden kopyalanmıştır.
/// Yeni kayıt eklerken aynı kural korunmalı; soru metninden veya serbest
/// metinden sezgisel çeviri türetilmemelidir.
class LearnerLexicon {
  const LearnerLexicon._();

  static const Map<String, LearnerLexiconSource> sources = {
    'everyday_1': LearnerLexiconSource(
      id: 'everyday_1',
      titleKu: 'Silavkirin',
      titleTr: 'Selamlaşma',
      categoryKu: 'Rojane',
      categoryTr: 'Günlük',
    ),
    'everyday_2': LearnerLexiconSource(
      id: 'everyday_2',
      titleKu: 'Nasandin',
      titleTr: 'Tanışma',
      categoryKu: 'Rojane',
      categoryTr: 'Günlük',
    ),
    'everyday_3': LearnerLexiconSource(
      id: 'everyday_3',
      titleKu: 'Pratikên rojane',
      titleTr: 'Günlük pratik ifadeler',
      categoryKu: 'Rojane',
      categoryTr: 'Günlük',
    ),
    'grammar_1': LearnerLexiconSource(
      id: 'grammar_1',
      titleKu: 'Cînavkên kesane',
      titleTr: 'Şahıs zamirleri',
      categoryKu: 'Gramer',
      categoryTr: 'Dilbilgisi',
    ),
    'grammar_2': LearnerLexiconSource(
      id: 'grammar_2',
      titleKu: 'Tewandin',
      titleTr: 'Büküm (hal çekimi)',
      categoryKu: 'Gramer',
      categoryTr: 'Dilbilgisi',
    ),
    'culture_1': LearnerLexiconSource(
      id: 'culture_1',
      titleKu: 'Folklor û govend',
      titleTr: 'Folklor & halay',
      categoryKu: 'Çand',
      categoryTr: 'Kültür',
    ),
    'culture_2': LearnerLexiconSource(
      id: 'culture_2',
      titleKu: 'Cejn û cejndarî',
      titleTr: 'Bayramlar',
      categoryKu: 'Çand',
      categoryTr: 'Kültür',
    ),
    'food_1': LearnerLexiconSource(
      id: 'food_1',
      titleKu: 'Xwarinên bingehîn',
      titleTr: 'Temel yemekler',
      categoryKu: 'Xwarin',
      categoryTr: 'Yemek',
    ),
    'food_2': LearnerLexiconSource(
      id: 'food_2',
      titleKu: 'Fêkî û keskahî',
      titleTr: 'Meyve & sebzeler',
      categoryKu: 'Xwarin',
      categoryTr: 'Yemek',
    ),
    'animals_1': LearnerLexiconSource(
      id: 'animals_1',
      titleKu: 'Heywanên malê',
      titleTr: 'Evcil hayvanlar',
      categoryKu: 'Ajal',
      categoryTr: 'Hayvanlar',
    ),
    'animals_2': LearnerLexiconSource(
      id: 'animals_2',
      titleKu: 'Heywanên kovî',
      titleTr: 'Yabani hayvanlar',
      categoryKu: 'Ajal',
      categoryTr: 'Hayvanlar',
    ),
    'geography_1': LearnerLexiconSource(
      id: 'geography_1',
      titleKu: 'Erdnîgarîya Kurdistanê',
      titleTr: 'Coğrafya',
      categoryKu: 'Erdnîgarî',
      categoryTr: 'Coğrafya',
    ),
    'geography_2': LearnerLexiconSource(
      id: 'geography_2',
      titleKu: 'Aliyên erdnîgarî',
      titleTr: 'Yönler',
      categoryKu: 'Erdnîgarî',
      categoryTr: 'Coğrafya',
    ),
    'emotions_1': LearnerLexiconSource(
      id: 'emotions_1',
      titleKu: 'Hestên erênî',
      titleTr: 'Olumlu duygular',
      categoryKu: 'Hest',
      categoryTr: 'Duygular',
    ),
    'emotions_2': LearnerLexiconSource(
      id: 'emotions_2',
      titleKu: 'Hestên neyînî',
      titleTr: 'Olumsuz duygular',
      categoryKu: 'Hest',
      categoryTr: 'Duygular',
    ),
    'time_1': LearnerLexiconSource(
      id: 'time_1',
      titleKu: 'Roj û meh',
      titleTr: 'Günler & aylar',
      categoryKu: 'Demjimêr',
      categoryTr: 'Zaman',
    ),
    'time_2': LearnerLexiconSource(
      id: 'time_2',
      titleKu: 'Serdem û demjimêr',
      titleTr: 'Zaman dilimleri',
      categoryKu: 'Demjimêr',
      categoryTr: 'Zaman',
    ),
    'alphabet_1': LearnerLexiconSource(
      id: 'alphabet_1',
      titleKu: 'Alfabe',
      titleTr: 'Alfabe',
      categoryKu: 'Rojane',
      categoryTr: 'Günlük',
    ),
    'greetings_2': LearnerLexiconSource(
      id: 'greetings_2',
      titleKu: 'Silav û rêzdarî 2',
      titleTr: 'Selamlaşma ve nezaket 2',
      categoryKu: 'Rojane',
      categoryTr: 'Günlük',
    ),
    'intro_1': LearnerLexiconSource(
      id: 'intro_1',
      titleKu: 'Xwe nasandin',
      titleTr: 'Kendini tanıtma',
      categoryKu: 'Rojane',
      categoryTr: 'Günlük',
    ),
    'family_1': LearnerLexiconSource(
      id: 'family_1',
      titleKu: 'Malbat',
      titleTr: 'Aile',
      categoryKu: 'Rojane',
      categoryTr: 'Günlük',
    ),
    // Sunucu-yalnız dersler: yerel katalogda ders yok; çiftler
    // `supabase/2026-07-06_lesson_seed.sql` slaytlarından (bkz. aynı dosyadaki
    // sunucu slug -> yerel kimlik eşlemesi: `learning_lesson_aliases.dart`).
    'numbers_1': LearnerLexiconSource(
      id: 'numbers_1',
      titleKu: 'Hejmar',
      titleTr: 'Sayılar',
      categoryKu: 'Rojane',
      categoryTr: 'Günlük',
    ),
    'grammar_bun': LearnerLexiconSource(
      id: 'grammar_bun',
      titleKu: 'Lêkera "bûn"',
      titleTr: 'Olmak fiili',
      categoryKu: 'Gramer',
      categoryTr: 'Dilbilgisi',
    ),
    'culture_dengbeji': LearnerLexiconSource(
      id: 'culture_dengbeji',
      titleKu: 'Dengbêjî',
      titleTr: 'Dengbejlik',
      categoryKu: 'Çand',
      categoryTr: 'Kültür',
    ),
    'time_seasons': LearnerLexiconSource(
      id: 'time_seasons',
      titleKu: 'Demsal',
      titleTr: 'Mevsimler',
      categoryKu: 'Demjimêr',
      categoryTr: 'Zaman',
    ),
  };

  static const List<LearnerLexiconEntry> entries = [
    LearnerLexiconEntry(
      id: 'rojbas',
      termKu: 'Rojbaş',
      meaningTr: 'Günaydın / İyi günler',
      sourceId: 'everyday_1',
    ),
    LearnerLexiconEntry(
      id: 'evarbas',
      termKu: 'Êvarbaş',
      meaningTr: 'İyi akşamlar',
      sourceId: 'everyday_1',
    ),
    LearnerLexiconEntry(
      id: 'sevbas',
      termKu: 'Şevbaş',
      meaningTr: 'İyi geceler',
      sourceId: 'everyday_1',
    ),
    LearnerLexiconEntry(
      id: 'nave-te-ci-ye',
      termKu: 'Navê te çi ye?',
      meaningTr: 'Adın ne?',
      sourceId: 'everyday_2',
    ),
    LearnerLexiconEntry(
      id: 'nave-min-azad-e',
      termKu: 'Navê min Azad e',
      meaningTr: 'Benim adım Azad.',
      sourceId: 'everyday_2',
    ),
    LearnerLexiconEntry(
      id: 'tu-ji-ku-dere-yi',
      termKu: 'Tu ji ku derê yî?',
      meaningTr: 'Nerelisin?',
      sourceId: 'everyday_2',
    ),
    LearnerLexiconEntry(
      id: 'ez-ji-amede-me',
      termKu: 'Ez ji Amedê me',
      meaningTr: 'Amedliyim.',
      sourceId: 'everyday_2',
    ),
    LearnerLexiconEntry(
      id: 'fermo',
      termKu: 'Fermo',
      meaningTr: 'Buyurun',
      sourceId: 'everyday_3',
    ),
    LearnerLexiconEntry(
      id: 'kerem-bike',
      termKu: 'Kerem bike',
      meaningTr: 'Buyur / Geç',
      sourceId: 'everyday_3',
    ),
    LearnerLexiconEntry(
      id: 'spas',
      termKu: 'Spas',
      meaningTr: 'Teşekkürler / Sağ ol',
      sourceId: 'everyday_3',
    ),
    LearnerLexiconEntry(
      id: 'ji-kerema-xwe',
      termKu: 'Ji kerema xwe',
      meaningTr: 'Lütfen',
      sourceId: 'everyday_3',
    ),
    LearnerLexiconEntry(
      id: 'bibexsine',
      termKu: 'Bibexşîne',
      meaningTr: 'Özür dilerim / Affet',
      sourceId: 'everyday_3',
    ),
    LearnerLexiconEntry(
      id: 'ez',
      termKu: 'Ez',
      meaningTr: 'Ben',
      sourceId: 'grammar_1',
    ),
    LearnerLexiconEntry(
      id: 'tu',
      termKu: 'Tu',
      meaningTr: 'Sen',
      sourceId: 'grammar_1',
    ),
    LearnerLexiconEntry(
      id: 'ew',
      termKu: 'Ew',
      meaningTr: 'O',
      sourceId: 'grammar_1',
    ),
    LearnerLexiconEntry(
      id: 'em',
      termKu: 'Em',
      meaningTr: 'Biz',
      sourceId: 'grammar_1',
    ),
    LearnerLexiconEntry(
      id: 'hun',
      termKu: 'Hûn',
      meaningTr: 'Siz',
      sourceId: 'grammar_1',
    ),
    LearnerLexiconEntry(
      id: 'min',
      termKu: 'Min',
      meaningTr: 'Beni / Bana / Benim',
      sourceId: 'grammar_2',
    ),
    LearnerLexiconEntry(
      id: 'te',
      termKu: 'Te',
      meaningTr: 'Seni / Sana / Senin',
      sourceId: 'grammar_2',
    ),
    LearnerLexiconEntry(
      id: 'wi-we',
      termKu: 'Wî (nêr) / Wê (mê)',
      meaningTr: 'Onu / Ona / Onun',
      sourceId: 'grammar_2',
    ),
    LearnerLexiconEntry(
      id: 'govend',
      termKu: 'Govend',
      meaningTr: 'Halay',
      sourceId: 'culture_1',
    ),
    LearnerLexiconEntry(
      id: 'dilan',
      termKu: 'Dilan',
      meaningTr: 'Düğün / Eğlence',
      sourceId: 'culture_1',
    ),
    LearnerLexiconEntry(
      id: 'sahi',
      termKu: 'Şahî',
      meaningTr: 'Şenlik',
      sourceId: 'culture_1',
    ),
    LearnerLexiconEntry(
      id: 'cejna-remezane',
      termKu: 'Cejna Remezanê',
      meaningTr: 'Ramazan Bayramı',
      sourceId: 'culture_2',
    ),
    LearnerLexiconEntry(
      id: 'cejna-qurbane',
      termKu: 'Cejna Qurbanê',
      meaningTr: 'Kurban Bayramı',
      sourceId: 'culture_2',
    ),
    LearnerLexiconEntry(
      id: 'nan',
      termKu: 'Nan',
      meaningTr: 'Ekmek',
      sourceId: 'food_1',
    ),
    LearnerLexiconEntry(
      id: 'av',
      termKu: 'Av',
      meaningTr: 'Su',
      sourceId: 'food_1',
    ),
    LearnerLexiconEntry(
      id: 'gost',
      termKu: 'Goşt',
      meaningTr: 'Et',
      sourceId: 'food_1',
    ),
    LearnerLexiconEntry(
      id: 'mast',
      termKu: 'Mast',
      meaningTr: 'Yoğurt',
      sourceId: 'food_1',
    ),
    LearnerLexiconEntry(
      id: 'taste',
      termKu: 'Taştê',
      meaningTr: 'Kahvaltı',
      sourceId: 'food_1',
    ),
    LearnerLexiconEntry(
      id: 'firavin',
      termKu: 'Firavîn',
      meaningTr: 'Öğle yemeği',
      sourceId: 'food_1',
    ),
    LearnerLexiconEntry(
      id: 'siv',
      termKu: 'Şîv',
      meaningTr: 'Akşam yemeği',
      sourceId: 'food_1',
    ),
    LearnerLexiconEntry(
      id: 'sev',
      termKu: 'Sêv',
      meaningTr: 'Elma',
      sourceId: 'food_2',
    ),
    LearnerLexiconEntry(
      id: 'hinar',
      termKu: 'Hinar',
      meaningTr: 'Nar',
      sourceId: 'food_2',
    ),
    LearnerLexiconEntry(
      id: 'tiri',
      termKu: 'Tirî',
      meaningTr: 'Üzüm',
      sourceId: 'food_2',
    ),
    LearnerLexiconEntry(
      id: 'hejir',
      termKu: 'Hejîr',
      meaningTr: 'İncir',
      sourceId: 'food_2',
    ),
    LearnerLexiconEntry(
      id: 'pivaz',
      termKu: 'Pîvaz',
      meaningTr: 'Soğan',
      sourceId: 'food_2',
    ),
    LearnerLexiconEntry(
      id: 'sir',
      termKu: 'Sîr',
      meaningTr: 'Sarımsak',
      sourceId: 'food_2',
    ),
    LearnerLexiconEntry(
      id: 'bacan',
      termKu: 'Bacan',
      meaningTr: 'Patlıcan / Domates',
      sourceId: 'food_2',
    ),
    LearnerLexiconEntry(
      id: 'kucik-seg',
      termKu: 'Kûçik / Seg',
      meaningTr: 'Köpek',
      sourceId: 'animals_1',
    ),
    LearnerLexiconEntry(
      id: 'pisik',
      termKu: 'Pisîk',
      meaningTr: 'Kedi',
      sourceId: 'animals_1',
    ),
    LearnerLexiconEntry(
      id: 'hesp',
      termKu: 'Hesp',
      meaningTr: 'At',
      sourceId: 'animals_1',
    ),
    LearnerLexiconEntry(
      id: 'celek',
      termKu: 'Çêlek',
      meaningTr: 'İnek',
      sourceId: 'animals_1',
    ),
    LearnerLexiconEntry(
      id: 'mih',
      termKu: 'Mîh',
      meaningTr: 'Koyun',
      sourceId: 'animals_1',
    ),
    LearnerLexiconEntry(
      id: 'bizin',
      termKu: 'Bizin',
      meaningTr: 'Keçi',
      sourceId: 'animals_1',
    ),
    LearnerLexiconEntry(
      id: 'ser',
      termKu: 'Şêr',
      meaningTr: 'Aslan',
      sourceId: 'animals_2',
    ),
    LearnerLexiconEntry(
      id: 'gur',
      termKu: 'Gur',
      meaningTr: 'Kurt',
      sourceId: 'animals_2',
    ),
    LearnerLexiconEntry(
      id: 'ruvi',
      termKu: 'Rûvî',
      meaningTr: 'Tilki',
      sourceId: 'animals_2',
    ),
    LearnerLexiconEntry(
      id: 'hirc',
      termKu: 'Hirç',
      meaningTr: 'Ayı',
      sourceId: 'animals_2',
    ),
    LearnerLexiconEntry(
      id: 'eylo',
      termKu: 'Eylo',
      meaningTr: 'Kartal',
      sourceId: 'animals_2',
    ),
    LearnerLexiconEntry(
      id: 'kevok',
      termKu: 'Kevok',
      meaningTr: 'Güvercin',
      sourceId: 'animals_2',
    ),
    LearnerLexiconEntry(
      id: 'qijak',
      termKu: 'Qijak',
      meaningTr: 'Karga',
      sourceId: 'animals_2',
      forms: ['qijik'],
    ),
    LearnerLexiconEntry(
      id: 'ceme-dicle',
      termKu: 'Çemê Dîcle',
      meaningTr: 'Dicle Nehri',
      sourceId: 'geography_1',
    ),
    LearnerLexiconEntry(
      id: 'ceme-firat',
      termKu: 'Çemê Firat',
      meaningTr: 'Fırat Nehri',
      sourceId: 'geography_1',
    ),
    LearnerLexiconEntry(
      id: 'bakur',
      termKu: 'Bakur',
      meaningTr: 'Kuzey',
      sourceId: 'geography_2',
    ),
    LearnerLexiconEntry(
      id: 'basur',
      termKu: 'Başûr',
      meaningTr: 'Güney',
      sourceId: 'geography_2',
    ),
    LearnerLexiconEntry(
      id: 'rojhilat',
      termKu: 'Rojhilat',
      meaningTr: 'Doğu',
      sourceId: 'geography_2',
    ),
    LearnerLexiconEntry(
      id: 'rojava',
      termKu: 'Rojava',
      meaningTr: 'Batı',
      sourceId: 'geography_2',
    ),
    LearnerLexiconEntry(
      id: 'jor',
      termKu: 'Jor / Jorîn',
      meaningTr: 'Yukarı',
      sourceId: 'geography_2',
    ),
    LearnerLexiconEntry(
      id: 'jer',
      termKu: 'Jêr / Jêrîn',
      meaningTr: 'Aşağı',
      sourceId: 'geography_2',
    ),
    LearnerLexiconEntry(
      id: 'navin',
      termKu: 'Navîn',
      meaningTr: 'Orta',
      sourceId: 'geography_2',
    ),
    LearnerLexiconEntry(
      id: 'kefxwes',
      termKu: 'Kêfxweş',
      meaningTr: 'Mutlu',
      sourceId: 'emotions_1',
    ),
    LearnerLexiconEntry(
      id: 'dilsad',
      termKu: 'Dilşad',
      meaningTr: 'Sevinçli',
      sourceId: 'emotions_1',
    ),
    LearnerLexiconEntry(
      id: 'evindar',
      termKu: 'Evîndar',
      meaningTr: 'Aşık',
      sourceId: 'emotions_1',
    ),
    LearnerLexiconEntry(
      id: 'asti',
      termKu: 'Aştî',
      meaningTr: 'Barış',
      sourceId: 'emotions_1',
    ),
    LearnerLexiconEntry(
      id: 'hevi',
      termKu: 'Hêvî',
      meaningTr: 'Umut',
      sourceId: 'emotions_1',
    ),
    LearnerLexiconEntry(
      id: 'baweri',
      termKu: 'Bawerî',
      meaningTr: 'İnanç / Güven',
      sourceId: 'emotions_1',
    ),
    LearnerLexiconEntry(
      id: 'xemgin',
      termKu: 'Xemgîn',
      meaningTr: 'Üzgün',
      sourceId: 'emotions_2',
    ),
    LearnerLexiconEntry(
      id: 'hersbuyi',
      termKu: 'Hêrsbûyî',
      meaningTr: 'Öfkeli',
      sourceId: 'emotions_2',
    ),
    LearnerLexiconEntry(
      id: 'tirsiyayi',
      termKu: 'Tirsiyayî',
      meaningTr: 'Korkmuş',
      sourceId: 'emotions_2',
    ),
    LearnerLexiconEntry(
      id: 'behevi',
      termKu: 'Bêhêvî',
      meaningTr: 'Umutsuz',
      sourceId: 'emotions_2',
    ),
    LearnerLexiconEntry(
      id: 'dilsikesti',
      termKu: 'Dilşikestî',
      meaningTr: 'Kalbi kırık',
      sourceId: 'emotions_2',
    ),
    LearnerLexiconEntry(
      id: 'rebendan',
      termKu: 'Rêbendan',
      meaningTr: 'Ocak',
      sourceId: 'time_1',
    ),
    LearnerLexiconEntry(
      id: 'resemeh',
      termKu: 'Reşemeh',
      meaningTr: 'Şubat',
      sourceId: 'time_1',
    ),
    LearnerLexiconEntry(
      id: 'adar',
      termKu: 'Adar',
      meaningTr: 'Mart',
      sourceId: 'time_1',
    ),
    LearnerLexiconEntry(
      id: 'nisan',
      termKu: 'Nîsan',
      meaningTr: 'Nisan',
      sourceId: 'time_1',
    ),
    LearnerLexiconEntry(
      id: 'gulan',
      termKu: 'Gulan',
      meaningTr: 'Mayıs',
      sourceId: 'time_1',
    ),
    LearnerLexiconEntry(
      id: 'heziran',
      termKu: 'Hezîran',
      meaningTr: 'Haziran',
      sourceId: 'time_1',
    ),
    LearnerLexiconEntry(
      id: 'sibeh',
      termKu: 'Sibeh',
      meaningTr: 'Sabah',
      sourceId: 'time_2',
      forms: ['sibehê', 'sibeha'],
    ),
    LearnerLexiconEntry(
      id: 'nivro',
      termKu: 'Nîvro',
      meaningTr: 'Öğle',
      sourceId: 'time_2',
    ),
    LearnerLexiconEntry(
      id: 'evar',
      termKu: 'Êvar',
      meaningTr: 'Akşam',
      sourceId: 'time_2',
      forms: ['êvarê', 'êvara'],
    ),
    LearnerLexiconEntry(
      id: 'sev-time',
      termKu: 'Şev',
      meaningTr: 'Gece',
      sourceId: 'time_2',
      forms: ['şevê', 'şeva'],
    ),
    LearnerLexiconEntry(
      id: 'duh',
      termKu: 'Duh',
      meaningTr: 'Dün',
      sourceId: 'time_2',
    ),
    LearnerLexiconEntry(
      id: 'iro',
      termKu: 'Îro',
      meaningTr: 'Bugün',
      sourceId: 'time_2',
    ),
    LearnerLexiconEntry(
      id: 'sibe',
      termKu: 'Sibe',
      meaningTr: 'Yarın',
      sourceId: 'time_2',
    ),
    LearnerLexiconEntry(
      id: 'alfabe',
      termKu: 'Alfabe',
      meaningTr: 'Alfabe',
      sourceId: 'alphabet_1',
      forms: ['alfabeya'],
    ),
    LearnerLexiconEntry(
      id: 'tip',
      termKu: 'Tîp',
      meaningTr: 'Harf',
      sourceId: 'alphabet_1',
      forms: ['tîpa', 'tîpên'],
    ),
    LearnerLexiconEntry(
      id: 'dengder',
      termKu: 'Dengdêr',
      meaningTr: 'Ünlü harf',
      sourceId: 'alphabet_1',
    ),
    LearnerLexiconEntry(
      id: 'dengdar',
      termKu: 'Dengdar',
      meaningTr: 'Ünsüz harf',
      sourceId: 'alphabet_1',
    ),
    LearnerLexiconEntry(
      id: 'cil',
      termKu: 'Cil',
      meaningTr: 'Giysi',
      sourceId: 'alphabet_1',
    ),
    LearnerLexiconEntry(
      id: 'cay',
      termKu: 'Çay',
      meaningTr: 'Çay',
      sourceId: 'alphabet_1',
    ),
    LearnerLexiconEntry(
      id: 'dar',
      termKu: 'Dar',
      meaningTr: 'Ağaç',
      sourceId: 'alphabet_1',
    ),
    LearnerLexiconEntry(
      id: 'feki',
      termKu: 'Fêkî',
      meaningTr: 'Meyve',
      sourceId: 'alphabet_1',
    ),
    LearnerLexiconEntry(
      id: 'gul',
      termKu: 'Gul',
      meaningTr: 'Gül',
      sourceId: 'alphabet_1',
    ),
    LearnerLexiconEntry(
      id: 'heval',
      termKu: 'Heval',
      meaningTr: 'Arkadaş',
      sourceId: 'alphabet_1',
    ),
    LearnerLexiconEntry(
      id: 'ker',
      termKu: 'Ker',
      meaningTr: 'Eşek',
      sourceId: 'alphabet_1',
    ),
    LearnerLexiconEntry(
      id: 'lev',
      termKu: 'Lêv',
      meaningTr: 'Dudak',
      sourceId: 'alphabet_1',
    ),
    LearnerLexiconEntry(
      id: 'mal',
      termKu: 'Mal',
      meaningTr: 'Ev',
      sourceId: 'alphabet_1',
      forms: ['malê', 'mala'],
    ),
    LearnerLexiconEntry(
      id: 'ode',
      termKu: 'Ode',
      meaningTr: 'Oda',
      sourceId: 'alphabet_1',
    ),
    LearnerLexiconEntry(
      id: 'qelem',
      termKu: 'Qelem',
      meaningTr: 'Kalem',
      sourceId: 'alphabet_1',
    ),
    LearnerLexiconEntry(
      id: 'roj',
      termKu: 'Roj',
      meaningTr: 'Gün / Güneş',
      sourceId: 'alphabet_1',
      forms: ['rojê', 'roja'],
    ),
    LearnerLexiconEntry(
      id: 'welat',
      termKu: 'Welat',
      meaningTr: 'Ülke',
      sourceId: 'alphabet_1',
    ),
    LearnerLexiconEntry(
      id: 'dil',
      termKu: 'Dil',
      meaningTr: 'Kalp',
      sourceId: 'alphabet_1',
    ),
    LearnerLexiconEntry(
      id: 'dur',
      termKu: 'Dûr',
      meaningTr: 'Uzak',
      sourceId: 'alphabet_1',
    ),
    LearnerLexiconEntry(
      id: 'ev',
      termKu: 'Ev',
      meaningTr: 'Bu',
      sourceId: 'alphabet_1',
    ),
    LearnerLexiconEntry(
      id: 'silav',
      termKu: 'Silav',
      meaningTr: 'Selam',
      sourceId: 'greetings_2',
    ),
    LearnerLexiconEntry(
      id: 'bi-xer-hati',
      termKu: 'Bi xêr hatî',
      meaningTr: 'Hoş geldin',
      sourceId: 'greetings_2',
      forms: ['hatî', 'hatin'],
    ),
    LearnerLexiconEntry(
      id: 'sibeha-te-bi-xer',
      termKu: 'Sibeha te bi xêr',
      meaningTr: 'Günaydın',
      sourceId: 'greetings_2',
    ),
    LearnerLexiconEntry(
      id: 'evara-te-bi-xer',
      termKu: 'Êvara te bi xêr',
      meaningTr: 'İyi akşamlar',
      sourceId: 'greetings_2',
    ),
    LearnerLexiconEntry(
      id: 'seva-te-bi-xer',
      termKu: 'Şeva te bi xêr',
      meaningTr: 'İyi geceler',
      sourceId: 'greetings_2',
    ),
    LearnerLexiconEntry(
      id: 'hun-cawa-ne',
      termKu: 'Hûn çawa ne?',
      meaningTr: 'Nasılsınız?',
      sourceId: 'greetings_2',
    ),
    LearnerLexiconEntry(
      id: 'ez-bas-im',
      termKu: 'Ez baş im',
      meaningTr: 'İyiyim',
      sourceId: 'greetings_2',
    ),
    LearnerLexiconEntry(
      id: 'ez-gelek-bas-im',
      termKu: 'Ez gelek baş im',
      meaningTr: 'Çok iyiyim',
      sourceId: 'greetings_2',
    ),
    LearnerLexiconEntry(
      id: 'cawa',
      termKu: 'Çawa',
      meaningTr: 'Nasıl',
      sourceId: 'greetings_2',
    ),
    LearnerLexiconEntry(
      id: 'bas',
      termKu: 'Baş',
      meaningTr: 'İyi',
      sourceId: 'greetings_2',
    ),
    LearnerLexiconEntry(
      id: 'gelek',
      termKu: 'Gelek',
      meaningTr: 'Çok',
      sourceId: 'greetings_2',
    ),
    LearnerLexiconEntry(
      id: 'gelek-spas',
      termKu: 'Gelek spas',
      meaningTr: 'Çok teşekkürler',
      sourceId: 'greetings_2',
    ),
    LearnerLexiconEntry(
      id: 'bibore',
      termKu: 'Bibore',
      meaningTr: 'Özür dilerim / Pardon',
      sourceId: 'greetings_2',
    ),
    LearnerLexiconEntry(
      id: 'bi-xatire-te',
      termKu: 'Bi xatirê te',
      meaningTr: 'Hoşça kal',
      sourceId: 'greetings_2',
      forms: ['xatirê'],
    ),
    LearnerLexiconEntry(
      id: 'bi-xatire-we',
      termKu: 'Bi xatirê we',
      meaningTr: 'Hoşça kalın',
      sourceId: 'greetings_2',
    ),
    LearnerLexiconEntry(
      id: 'oxir-be',
      termKu: 'Oxir be',
      meaningTr: 'Güle güle',
      sourceId: 'greetings_2',
    ),
    LearnerLexiconEntry(
      id: 'xer',
      termKu: 'Xêr',
      meaningTr: 'Hayır / İyilik',
      sourceId: 'greetings_2',
    ),
    LearnerLexiconEntry(
      id: 'we',
      termKu: 'We',
      meaningTr: 'Size / Sizin (tewandî hal)',
      sourceId: 'greetings_2',
    ),
    LearnerLexiconEntry(
      id: 'nav',
      termKu: 'Nav',
      meaningTr: 'Ad / İsim',
      sourceId: 'intro_1',
      forms: ['navê'],
    ),
    LearnerLexiconEntry(
      id: 'nave-min-rojin-e',
      termKu: 'Navê min Rojîn e',
      meaningTr: 'Benim adım Rojîn.',
      sourceId: 'intro_1',
    ),
    LearnerLexiconEntry(
      id: 'rojin',
      termKu: 'Rojîn',
      meaningTr: 'Kız ismi',
      sourceId: 'intro_1',
    ),
    LearnerLexiconEntry(
      id: 'ci',
      termKu: 'Çi',
      meaningTr: 'Ne',
      sourceId: 'intro_1',
    ),
    LearnerLexiconEntry(
      id: 'tu-cend-sali-yi',
      termKu: 'Tu çend salî yî?',
      meaningTr: 'Kaç yaşındasın?',
      sourceId: 'intro_1',
    ),
    LearnerLexiconEntry(
      id: 'ez-bist-sali-me',
      termKu: 'Ez bîst salî me',
      meaningTr: 'Yirmi yaşındayım.',
      sourceId: 'intro_1',
    ),
    LearnerLexiconEntry(
      id: 'sal',
      termKu: 'Sal',
      meaningTr: 'Yıl',
      sourceId: 'intro_1',
      forms: ['salî'],
    ),
    LearnerLexiconEntry(
      id: 'cend',
      termKu: 'Çend',
      meaningTr: 'Kaç',
      sourceId: 'intro_1',
    ),
    LearnerLexiconEntry(
      id: 'ez-ji-wane-me',
      termKu: 'Ez ji Wanê me',
      meaningTr: 'Vanlıyım.',
      sourceId: 'intro_1',
    ),
    LearnerLexiconEntry(
      id: 'ji',
      termKu: 'Ji',
      meaningTr: '-den / -dan',
      sourceId: 'intro_1',
    ),
    LearnerLexiconEntry(
      id: 'ku',
      termKu: 'Ku',
      meaningTr: 'Nerede / Nere',
      sourceId: 'intro_1',
    ),
    LearnerLexiconEntry(
      id: 'dere',
      termKu: 'Der',
      meaningTr: 'Yer (ku derê = nere)',
      sourceId: 'intro_1',
      forms: ['derê'],
    ),
    LearnerLexiconEntry(
      id: 'wan',
      termKu: 'Wan',
      meaningTr: 'Van',
      sourceId: 'intro_1',
      forms: ['Wanê'],
    ),
    LearnerLexiconEntry(
      id: 'merdin',
      termKu: 'Mêrdîn',
      meaningTr: 'Mardin',
      sourceId: 'intro_1',
      forms: ['Mêrdînê'],
    ),
    LearnerLexiconEntry(
      id: 'stenbol',
      termKu: 'Stenbol',
      meaningTr: 'İstanbul',
      sourceId: 'intro_1',
      forms: ['Stenbolê'],
    ),
    LearnerLexiconEntry(
      id: 'kurd',
      termKu: 'Kurd',
      meaningTr: 'Kürt',
      sourceId: 'intro_1',
    ),
    LearnerLexiconEntry(
      id: 'pise',
      termKu: 'Pîşe',
      meaningTr: 'Meslek',
      sourceId: 'intro_1',
    ),
    LearnerLexiconEntry(
      id: 'xwendekar',
      termKu: 'Xwendekar',
      meaningTr: 'Öğrenci',
      sourceId: 'intro_1',
    ),
    LearnerLexiconEntry(
      id: 'mamoste',
      termKu: 'Mamoste',
      meaningTr: 'Öğretmen',
      sourceId: 'intro_1',
    ),
    LearnerLexiconEntry(
      id: 'doktor',
      termKu: 'Doktor',
      meaningTr: 'Doktor',
      sourceId: 'intro_1',
    ),
    LearnerLexiconEntry(
      id: 'karker',
      termKu: 'Karker',
      meaningTr: 'İşçi',
      sourceId: 'intro_1',
    ),
    LearnerLexiconEntry(
      id: 'kurdi',
      termKu: 'Kurdî',
      meaningTr: 'Kürtçe',
      sourceId: 'intro_1',
    ),
    LearnerLexiconEntry(
      id: 'kurmanci',
      termKu: 'Kurmancî',
      meaningTr: 'Kurmancî (Kürtçenin bir lehçesi)',
      sourceId: 'intro_1',
    ),
    LearnerLexiconEntry(
      id: 'tirki',
      termKu: 'Tirkî',
      meaningTr: 'Türkçe',
      sourceId: 'intro_1',
    ),
    LearnerLexiconEntry(
      id: 'zanin',
      termKu: 'Zanîn',
      meaningTr: 'Bilmek',
      sourceId: 'intro_1',
      forms: ['dizanim', 'dizanî', 'dizane'],
    ),
    LearnerLexiconEntry(
      id: 'bi',
      termKu: 'Bi',
      meaningTr: 'İle / -le / -ce (dil)',
      sourceId: 'intro_1',
    ),
    LearnerLexiconEntry(
      id: 'malbat',
      termKu: 'Malbat',
      meaningTr: 'Aile',
      sourceId: 'family_1',
      forms: ['malbata'],
    ),
    LearnerLexiconEntry(
      id: 'de',
      termKu: 'Dê',
      meaningTr: 'Anne',
      sourceId: 'family_1',
    ),
    LearnerLexiconEntry(
      id: 'bav',
      termKu: 'Bav',
      meaningTr: 'Baba',
      sourceId: 'family_1',
      forms: ['bavê'],
    ),
    LearnerLexiconEntry(
      id: 'bira',
      termKu: 'Bira',
      meaningTr: 'Erkek kardeş',
      sourceId: 'family_1',
      forms: ['birayê'],
    ),
    LearnerLexiconEntry(
      id: 'xwisk',
      termKu: 'Xwişk',
      meaningTr: 'Kız kardeş',
      sourceId: 'family_1',
      forms: ['xwişka'],
    ),
    LearnerLexiconEntry(
      id: 'kur',
      termKu: 'Kur',
      meaningTr: 'Oğul / Erkek çocuk',
      sourceId: 'family_1',
      forms: ['kurê'],
    ),
    LearnerLexiconEntry(
      id: 'kec',
      termKu: 'Keç',
      meaningTr: 'Kız (çocuk)',
      sourceId: 'family_1',
      forms: ['keça'],
    ),
    LearnerLexiconEntry(
      id: 'dapir',
      termKu: 'Dapîr',
      meaningTr: 'Büyükanne',
      sourceId: 'family_1',
      forms: ['dapîra'],
    ),
    LearnerLexiconEntry(
      id: 'bapir',
      termKu: 'Bapîr',
      meaningTr: 'Büyükbaba',
      sourceId: 'family_1',
      forms: ['bapîrê'],
    ),
    LearnerLexiconEntry(
      id: 'mam',
      termKu: 'Mam',
      meaningTr: 'Amca',
      sourceId: 'family_1',
      forms: ['mamê'],
    ),
    LearnerLexiconEntry(
      id: 'met',
      termKu: 'Met',
      meaningTr: 'Hala',
      sourceId: 'family_1',
      forms: ['meta'],
    ),
    LearnerLexiconEntry(
      id: 'xal',
      termKu: 'Xal',
      meaningTr: 'Dayı',
      sourceId: 'family_1',
      forms: ['xalê'],
    ),
    LearnerLexiconEntry(
      id: 'xalti',
      termKu: 'Xaltî',
      meaningTr: 'Teyze',
      sourceId: 'family_1',
      forms: ['xalet', 'xaltiya'],
    ),
    LearnerLexiconEntry(
      id: 'jin',
      termKu: 'Jin',
      meaningTr: 'Kadın / Eş',
      sourceId: 'family_1',
      forms: ['jina'],
    ),
    LearnerLexiconEntry(
      id: 'mer',
      termKu: 'Mêr',
      meaningTr: 'Erkek / Koca',
      sourceId: 'family_1',
      forms: ['mêrê'],
    ),
    LearnerLexiconEntry(
      id: 'zarok',
      termKu: 'Zarok',
      meaningTr: 'Çocuk',
      sourceId: 'family_1',
      forms: ['zarokê'],
    ),
    LearnerLexiconEntry(
      id: 'ev-de-ye',
      termKu: 'Ev dê ye',
      meaningTr: 'Bu anne.',
      sourceId: 'family_1',
    ),
    LearnerLexiconEntry(
      id: 'ev-bave-min-e',
      termKu: 'Ev bavê min e',
      meaningTr: 'Bu benim babam.',
      sourceId: 'family_1',
    ),
    LearnerLexiconEntry(
      id: 'de-u-bav-li-male-ne',
      termKu: 'Dê û bav li malê ne',
      meaningTr: 'Anne ve baba evde.',
      sourceId: 'family_1',
    ),
    LearnerLexiconEntry(
      id: 'u',
      termKu: 'Û',
      meaningTr: 'Ve',
      sourceId: 'family_1',
    ),
    LearnerLexiconEntry(
      id: 'li',
      termKu: 'Li',
      meaningTr: '-de / -da (yer)',
      sourceId: 'family_1',
    ),
    LearnerLexiconEntry(
      id: 'xwarin',
      termKu: 'Xwarin',
      meaningTr: 'Yemek yemek',
      sourceId: 'food_1',
      forms: ['dixwim'],
    ),
    LearnerLexiconEntry(
      id: 'vexwarin',
      termKu: 'Vexwarin',
      meaningTr: 'İçmek',
      sourceId: 'food_1',
      forms: ['vedixwim'],
    ),
    LearnerLexiconEntry(
      id: 'gotin',
      termKu: 'Gotin',
      meaningTr: 'Söylemek',
      sourceId: 'greetings_2',
      forms: ['dibêjin', 'dibêjim', 'dibêjî'],
    ),
    LearnerLexiconEntry(
      id: 'cun',
      termKu: 'Çûn',
      meaningTr: 'Gitmek',
      sourceId: 'time_2',
      forms: ['diçim'],
    ),
    LearnerLexiconEntry(
      id: 'dawet',
      termKu: 'Dawet',
      meaningTr: 'Düğün',
      sourceId: 'culture_1',
    ),
    LearnerLexiconEntry(
      id: 'yek',
      termKu: 'Yek',
      meaningTr: 'Bir',
      sourceId: 'numbers_1',
    ),
    LearnerLexiconEntry(
      id: 'du',
      termKu: 'Du',
      meaningTr: 'İki',
      sourceId: 'numbers_1',
    ),
    LearnerLexiconEntry(
      id: 'se',
      termKu: 'Sê',
      meaningTr: 'Üç',
      sourceId: 'numbers_1',
    ),
    LearnerLexiconEntry(
      id: 'car',
      termKu: 'Çar',
      meaningTr: 'Dört',
      sourceId: 'numbers_1',
    ),
    LearnerLexiconEntry(
      id: 'penc',
      termKu: 'Pênc',
      meaningTr: 'Beş',
      sourceId: 'numbers_1',
    ),
    LearnerLexiconEntry(
      id: 'ses',
      termKu: 'Şeş',
      meaningTr: 'Altı',
      sourceId: 'numbers_1',
    ),
    LearnerLexiconEntry(
      id: 'heft',
      termKu: 'Heft',
      meaningTr: 'Yedi',
      sourceId: 'numbers_1',
    ),
    LearnerLexiconEntry(
      id: 'hest',
      termKu: 'Heşt',
      meaningTr: 'Sekiz',
      sourceId: 'numbers_1',
    ),
    LearnerLexiconEntry(
      id: 'neh',
      termKu: 'Neh',
      meaningTr: 'Dokuz',
      sourceId: 'numbers_1',
    ),
    LearnerLexiconEntry(
      id: 'deh',
      termKu: 'Deh',
      meaningTr: 'On',
      sourceId: 'numbers_1',
    ),
    LearnerLexiconEntry(
      id: 'bist',
      termKu: 'Bîst',
      meaningTr: 'Yirmi',
      sourceId: 'numbers_1',
    ),
    LearnerLexiconEntry(
      id: 'si',
      termKu: 'Sî',
      meaningTr: 'Otuz',
      sourceId: 'numbers_1',
    ),
    LearnerLexiconEntry(
      id: 'cil-2',
      termKu: 'Çil',
      meaningTr: 'Kırk',
      sourceId: 'numbers_1',
    ),
    LearnerLexiconEntry(
      id: 'penci',
      termKu: 'Pêncî',
      meaningTr: 'Elli',
      sourceId: 'numbers_1',
    ),
    LearnerLexiconEntry(
      id: 'sest',
      termKu: 'Şêst',
      meaningTr: 'Altmış',
      sourceId: 'numbers_1',
    ),
    LearnerLexiconEntry(
      id: 'hefte',
      termKu: 'Heftê',
      meaningTr: 'Yetmiş',
      sourceId: 'numbers_1',
    ),
    LearnerLexiconEntry(
      id: 'heste',
      termKu: 'Heştê',
      meaningTr: 'Seksen',
      sourceId: 'numbers_1',
    ),
    LearnerLexiconEntry(
      id: 'nod',
      termKu: 'Nod',
      meaningTr: 'Doksan',
      sourceId: 'numbers_1',
    ),
    LearnerLexiconEntry(
      id: 'sed',
      termKu: 'Sed',
      meaningTr: 'Yüz',
      sourceId: 'numbers_1',
    ),
    LearnerLexiconEntry(
      id: 'hezar',
      termKu: 'Hezar',
      meaningTr: 'Bin',
      sourceId: 'numbers_1',
    ),
    LearnerLexiconEntry(
      id: 'bun',
      termKu: 'Bûn',
      meaningTr: 'Olmak (im, yî, e, in...)',
      sourceId: 'grammar_bun',
      forms: ['im', 'yî', 'î', 'e', 'ye', 'me', 'in', 'ne'],
    ),
    LearnerLexiconEntry(
      id: 'dengbej',
      termKu: 'Dengbêj',
      meaningTr: 'Halk ozanı',
      sourceId: 'culture_dengbeji',
      forms: ['dengbêjan'],
    ),
    LearnerLexiconEntry(
      id: 'kilam',
      termKu: 'Kilam',
      meaningTr: 'Ezgi / Türkü',
      sourceId: 'culture_dengbeji',
      forms: ['kilamên'],
    ),
    LearnerLexiconEntry(
      id: 'stran',
      termKu: 'Stran',
      meaningTr: 'Şarkı',
      sourceId: 'culture_dengbeji',
      forms: ['stranên'],
    ),
    LearnerLexiconEntry(
      id: 'bihar',
      termKu: 'Bihar',
      meaningTr: 'İlkbahar',
      sourceId: 'time_seasons',
      forms: ['biharê'],
    ),
    LearnerLexiconEntry(
      id: 'havin',
      termKu: 'Havîn',
      meaningTr: 'Yaz',
      sourceId: 'time_seasons',
      forms: ['havînê'],
    ),
    LearnerLexiconEntry(
      id: 'payiz',
      termKu: 'Payîz',
      meaningTr: 'Sonbahar',
      sourceId: 'time_seasons',
      forms: ['payîzê'],
    ),
    LearnerLexiconEntry(
      id: 'zivistan',
      termKu: 'Zivistan',
      meaningTr: 'Kış',
      sourceId: 'time_seasons',
      forms: ['zivistanê'],
    ),
    LearnerLexiconEntry(
      id: 'tu-cawa-yi',
      termKu: 'Tu çawa yî?',
      meaningTr: 'Nasılsın?',
      sourceId: 'everyday_1',
    ),
    LearnerLexiconEntry(
      id: 'ez-bas-im-spas-dikim',
      termKu: 'Ez baş im, spas dikim',
      meaningTr: 'İyiyim, teşekkür ederim.',
      sourceId: 'everyday_1',
    ),
  ];

  static LearnerLexiconSource sourceFor(LearnerLexiconEntry entry) {
    final source = sources[entry.sourceId];
    assert(source != null, 'Unknown learner lexicon source: ${entry.sourceId}');
    return source!;
  }

  static List<LearnerLexiconEntry> entriesForSource(String sourceId) {
    return List.unmodifiable(
      entries.where((entry) => entry.sourceId == sourceId),
    );
  }

  /// Aramada KARŞILAŞTIRMA için katlanmış biçim: büyük/küçük harf, Türkçe ve
  /// Kurmancî aksanları yok sayılır (`cay` → `çay`, `sev` → `şev`, `kopek` →
  /// `köpek`, `evar` → `êvar`). `x`, `q`, `w` gibi harfler başka sesleri
  /// gösterdiği için KATLANMAZ; yalnız aksan işareti taşıyanlar sade harfe
  /// iner. Ekranda gösterilen metin hiç değişmez.
  ///
  /// Eskiden yalnız `toLowerCase()` vardı: Türkçe klavyeyle yazılan `cay`
  /// `Çay` maddesini bulmuyordu; öğrenen sözcüğün yazımını bilmediği için
  /// aratıyor, yazımı bilmeden doğru yazımı yazması isteniyordu.
  static String foldForSearch(String value) {
    final lowered = value
        .trim()
        .replaceAll('İ', 'i')
        .replaceAll('I', 'ı')
        .toLowerCase();
    final buffer = StringBuffer();
    for (final rune in lowered.runes) {
      // Ayrık (NFD) yazılmış aksanlar: `e` + U+0302 (ê), `s` + U+0327 (ş).
      // Taban harf kalır, birleştirici işaret düşer.
      if (rune >= 0x0300 && rune <= 0x036F) continue;
      final char = String.fromCharCode(rune);
      buffer.write(_accentFold[char] ?? char);
    }
    return buffer.toString().replaceAll(RegExp(r'\s+'), ' ');
  }

  static const Map<String, String> _accentFold = {
    'â': 'a',
    'ç': 'c',
    'ê': 'e',
    'î': 'i',
    'ı': 'i',
    'ô': 'o',
    'ö': 'o',
    'ş': 's',
    'û': 'u',
    'ü': 'u',
    'ğ': 'g',
  };

  /// Metindeki TEK bir sözcükten sözlük maddesine: dokununca anlam balonu.
  ///
  /// Sıra: (1) katlanmış tam eşleşme (terim ya da biçim; `Kûçik / Seg`
  /// terimi iki ayrı sözcük sayılır), (2) tam eşleşme yoksa sözcüğün BAŞINI
  /// oluşturan en uzun sözlük sözcüğü (>= 4 harf; `welatê` → `Welat`: kök +
  /// ek). Tek harfli ya da kısa sözcükler yalnız tam eşleşir (`ez`, `tu`).
  /// Eşleşmezse `null`: sözcük dokunulabilir görünmez.
  static LearnerLexiconEntry? lookup(String token) {
    final key = foldForSearch(
      token,
    ).replaceAll(RegExp(r"[^\p{L}]", unicode: true), '');
    if (key.isEmpty) return null;
    final index = _wordIndex ??= _buildWordIndex();
    final exact = index[key];
    if (exact != null) return exact;
    LearnerLexiconEntry? best;
    var bestLength = 0;
    for (final item in index.entries) {
      final length = item.key.length;
      if (length >= 4 && length > bestLength && key.startsWith(item.key)) {
        best = item.value;
        bestLength = length;
      }
    }
    return best;
  }

  static Map<String, LearnerLexiconEntry>? _wordIndex;

  static Map<String, LearnerLexiconEntry> _buildWordIndex() {
    final index = <String, LearnerLexiconEntry>{};
    void add(String word, LearnerLexiconEntry entry) {
      final key = foldForSearch(
        word,
      ).replaceAll(RegExp(r"[^\p{L}]", unicode: true), '');
      if (key.isNotEmpty) index.putIfAbsent(key, () => entry);
    }

    for (final entry in entries) {
      for (final alternative in entry.termKu.split(' / ')) {
        // Tek sözcüklü terimler; öbekler (`Navê te çi ye?`) kendi
        // sözcükleriyle ayrı maddelerde zaten durur.
        if (!alternative.trim().contains(' ')) add(alternative, entry);
      }
      for (final form in entry.forms) {
        add(form, entry);
      }
    }
    return index;
  }

  /// Arama: terim, anlam ve biçimlerde aksansız eşleşme; sonuçlar önce tam
  /// eşleşen, sonra öneki eşleşen, sonra içinde geçen maddeler olarak
  /// sıralanır (eşit derecede olanlar sözlük sırasını korur).
  static List<LearnerLexiconEntry> search(String query) {
    final needle = foldForSearch(query);
    if (needle.isEmpty) return entries;

    final ranked = <(int, int, LearnerLexiconEntry)>[];
    for (final (index, entry) in entries.indexed) {
      final term = foldForSearch(entry.termKu);
      final forms = [for (final form in entry.forms) foldForSearch(form)];
      final meaning = foldForSearch(entry.meaningTr);
      final rank = _rank(needle, term, forms, meaning);
      if (rank != null) ranked.add((rank, index, entry));
    }
    ranked.sort((a, b) {
      final byRank = a.$1.compareTo(b.$1);
      return byRank != 0 ? byRank : a.$2.compareTo(b.$2);
    });
    return List.unmodifiable([for (final item in ranked) item.$3]);
  }

  static int? _rank(
    String needle,
    String term,
    List<String> forms,
    String meaning,
  ) {
    if (term == needle || forms.contains(needle)) return 0;
    if (term.startsWith(needle) || forms.any((f) => f.startsWith(needle))) {
      return 1;
    }
    if (term.contains(needle) || forms.any((f) => f.contains(needle))) {
      return 2;
    }
    if (meaning.contains(needle)) return 3;
    return null;
  }
}
