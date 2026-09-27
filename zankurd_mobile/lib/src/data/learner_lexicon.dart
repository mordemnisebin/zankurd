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
  });

  final String id;
  final String termKu;
  final String meaningTr;
  final String sourceId;
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
      titleKu: 'Pratikên Rojane',
      titleTr: 'Günlük Pratik İfadeler',
      categoryKu: 'Rojane',
      categoryTr: 'Günlük',
    ),
    'grammar_1': LearnerLexiconSource(
      id: 'grammar_1',
      titleKu: 'Cînavkên Kesane',
      titleTr: 'Şahıs Zamirleri',
      categoryKu: 'Gramer',
      categoryTr: 'Dilbilgisi',
    ),
    'grammar_2': LearnerLexiconSource(
      id: 'grammar_2',
      titleKu: 'Tewandin',
      titleTr: 'Büküm (Hal Çekimi)',
      categoryKu: 'Gramer',
      categoryTr: 'Dilbilgisi',
    ),
    'culture_1': LearnerLexiconSource(
      id: 'culture_1',
      titleKu: 'Folklor û Govend',
      titleTr: 'Folklor & Halay',
      categoryKu: 'Çand',
      categoryTr: 'Kültür',
    ),
    'culture_2': LearnerLexiconSource(
      id: 'culture_2',
      titleKu: 'Cejn û Cejndarî',
      titleTr: 'Bayramlar',
      categoryKu: 'Çand',
      categoryTr: 'Kültür',
    ),
    'food_1': LearnerLexiconSource(
      id: 'food_1',
      titleKu: 'Xwarinên Bingehîn',
      titleTr: 'Temel Yemekler',
      categoryKu: 'Xwarin',
      categoryTr: 'Yemek',
    ),
    'food_2': LearnerLexiconSource(
      id: 'food_2',
      titleKu: 'Fêkî û Keskahî',
      titleTr: 'Meyve & Sebzeler',
      categoryKu: 'Xwarin',
      categoryTr: 'Yemek',
    ),
    'animals_1': LearnerLexiconSource(
      id: 'animals_1',
      titleKu: 'Heywanên Malê',
      titleTr: 'Evcil Hayvanlar',
      categoryKu: 'Ajal',
      categoryTr: 'Hayvanlar',
    ),
    'animals_2': LearnerLexiconSource(
      id: 'animals_2',
      titleKu: 'Heywanên Kovî',
      titleTr: 'Yabani Hayvanlar',
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
      titleKu: 'Aliyên Erdnîgarî',
      titleTr: 'Yönler',
      categoryKu: 'Erdnîgarî',
      categoryTr: 'Coğrafya',
    ),
    'emotions_1': LearnerLexiconSource(
      id: 'emotions_1',
      titleKu: 'Hestên Erênî',
      titleTr: 'Olumlu Duygular',
      categoryKu: 'Hest',
      categoryTr: 'Duygular',
    ),
    'emotions_2': LearnerLexiconSource(
      id: 'emotions_2',
      titleKu: 'Hestên Neyînî',
      titleTr: 'Olumsuz Duygular',
      categoryKu: 'Hest',
      categoryTr: 'Duygular',
    ),
    'time_1': LearnerLexiconSource(
      id: 'time_1',
      titleKu: 'Roj û Meh',
      titleTr: 'Günler & Aylar',
      categoryKu: 'Demjimêr',
      categoryTr: 'Zaman',
    ),
    'time_2': LearnerLexiconSource(
      id: 'time_2',
      titleKu: 'Serdem û Demjimêr',
      titleTr: 'Zaman Dilimleri',
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
    ),
    LearnerLexiconEntry(
      id: 'sev-time',
      termKu: 'Şev',
      meaningTr: 'Gece',
      sourceId: 'time_2',
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

  static List<LearnerLexiconEntry> search(String query) {
    final needle = _normalize(query);
    if (needle.isEmpty) return entries;

    return List.unmodifiable(
      entries.where((entry) {
        return _normalize(entry.termKu).contains(needle) ||
            _normalize(entry.meaningTr).contains(needle);
      }),
    );
  }

  static String _normalize(String value) {
    return value
        .trim()
        .replaceAll('İ', 'i')
        .replaceAll('I', 'ı')
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ');
  }
}
