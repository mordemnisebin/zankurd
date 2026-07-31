import '../models/quiz_question.dart';

class SubcategoryInfo {
  final String id;
  final String nameKu;
  final String nameTr;
  final String descriptionKu;
  final String descriptionTr;

  const SubcategoryInfo({
    required this.id,
    required this.nameKu,
    required this.nameTr,
    required this.descriptionKu,
    required this.descriptionTr,
  });
}

class SubcategoryConfig {
  static const Map<String, List<SubcategoryInfo>> subcategories = {
    'Ziman': [
      SubcategoryInfo(
        id: 'reziman',
        nameKu: 'Rêziman',
        nameTr: 'Dilbilgisi / Gramer',
        descriptionKu: 'Rêzikên hevok û peyvan',
        descriptionTr: 'Cümle ve kelime kuralları',
      ),
      SubcategoryInfo(
        id: 'peyvnasi',
        nameKu: 'Peyvnasî',
        nameTr: 'Kelime Bilgisi',
        descriptionKu: 'Wateya peyvên Kurdî',
        descriptionTr: 'Kürtçe kelimelerin anlamı',
      ),
      SubcategoryInfo(
        id: 'rastnivisin',
        nameKu: 'Rastnivîsîn',
        nameTr: 'Yazım Kuralları',
        descriptionKu: 'Rastnivîsa herf û peyvan',
        descriptionTr: 'Harf ve kelimelerin doğru yazımı',
      ),
    ],
    'Çand': [
      SubcategoryInfo(
        id: 'folklor',
        nameKu: 'Folklor û Çîrok',
        nameTr: 'Folklor & Hikayeler',
        descriptionKu: 'Çanda gelêrî û çîrokên kurdî',
        descriptionTr: 'Kürt halk kültürü ve masalları',
      ),
      SubcategoryInfo(
        id: 'cejn',
        nameKu: 'Cejn û Dûmahî',
        nameTr: 'Bayramlar & Gelenekler',
        descriptionKu: 'Rojên taybet û kevneşopî',
        descriptionTr: 'Özel günler ve ananeler',
      ),
      SubcategoryInfo(
        id: 'dastangotin',
        nameKu: 'Dastangotin',
        nameTr: 'Destanlar',
        descriptionKu: 'Dastan û lehengên kurdî',
        descriptionTr: 'Kürt destanları ve kahramanları',
      ),
      SubcategoryInfo(
        id: 'tistonek',
        nameKu: 'Tiştonek / Bilmece',
        nameTr: 'Bilmeceler & Zekâ',
        descriptionKu: 'Bilmeceyên kurdî yên gelêrî',
        descriptionTr: 'Geleneksel Kürt bilmeceleri ve zeka soruları',
      ),
    ],
    'Dîrok': [
      SubcategoryInfo(
        id: 'diroka_kevn',
        nameKu: 'Dîroka Kevn',
        nameTr: 'Antik Tarih',
        descriptionKu: 'Serdemên kevnar ên kurdan',
        descriptionTr: 'Kürtlerin antik çağlardaki tarihi',
      ),
      SubcategoryInfo(
        id: 'diroka_nujen',
        nameKu: 'Dîroka Nûjen',
        nameTr: 'Modern Tarih',
        descriptionKu: 'Bûyerên sedsala paşîn',
        descriptionTr: 'Son yüzyılın önemli olayları',
      ),
      SubcategoryInfo(
        id: 'sexsiyet',
        nameKu: 'Şexsiyetên Dîrokî',
        nameTr: 'Tarihi Şahsiyetler',
        descriptionKu: 'Kesên navdar û pêşeng',
        descriptionTr: 'Öncü ve tanınmış şahsiyetler',
      ),
    ],
    'Edebiyat': [
      SubcategoryInfo(
        id: 'helbest',
        nameKu: 'Helbest',
        nameTr: 'Şiir',
        descriptionKu: 'Helbestvan û dîwanên kurdî',
        descriptionTr: 'Kürt şairleri ve divanları',
      ),
      SubcategoryInfo(
        id: 'klasik',
        nameKu: 'Klasîk',
        nameTr: 'Klasik Edebiyat',
        descriptionKu: 'Wêjeya klasîk a kurdî',
        descriptionTr: 'Klasik Kürt edebiyatı eserleri',
      ),
      SubcategoryInfo(
        id: 'roman',
        nameKu: 'Roman û Çîrok',
        nameTr: 'Roman & Öykü',
        descriptionKu: 'Nûserên roman û çîrokên nû',
        descriptionTr: 'Yeni dönem roman ve öykü yazarları',
      ),
    ],
    'Cografya': [
      SubcategoryInfo(
        id: 'ciya_cem',
        nameKu: 'Çiya û Çem',
        nameTr: 'Dağlar & Nehirler',
        descriptionKu: 'Erdnîgarîya fizîkî ya Kurdistanê',
        descriptionTr: 'Kürdistan\'ın fiziki coğrafyası',
      ),
      SubcategoryInfo(
        id: 'bajar_ci',
        nameKu: 'Bajar û Cî',
        nameTr: 'Şehirler & Mekanlar',
        descriptionKu: 'Bajar û navçeyên kurdî',
        descriptionTr: 'Kürt şehirleri ve bölgeleri',
      ),
      SubcategoryInfo(
        id: 'sinor_duma',
        nameKu: 'Sînor û Awa',
        nameTr: 'Sınırlar & Coğrafi Yapı',
        descriptionKu: 'Erdnîgarîya siyasî û xwezayî',
        descriptionTr: 'Siyasi coğrafya ve doğa yapısı',
      ),
    ],
    'Muzîk': [
      SubcategoryInfo(
        id: 'dengbeji',
        nameKu: 'Dengbêjî',
        nameTr: 'Dengbêjlik',
        descriptionKu: 'Kilam û stranên dengbêjan',
        descriptionTr: 'Dengbêj kilamları ve eserleri',
      ),
      SubcategoryInfo(
        id: 'nujen',
        nameKu: 'Muzîka Nûjen',
        nameTr: 'Modern Müzik',
        descriptionKu: 'Kom û stranbêjên nûjen',
        descriptionTr: 'Modern müzik grupları ve şarkıcıları',
      ),
      SubcategoryInfo(
        id: 'amur',
        nameKu: 'Amûrên Muzîkê',
        nameTr: 'Müzik Aletleri',
        descriptionKu: 'Saz, tembûr û amûrên kurdî',
        descriptionTr: 'Saz, tambur ve Kürt çalgıları',
      ),
    ],
    'Siyaset': [
      SubcategoryInfo(
        id: 'diroka_siyasi',
        nameKu: 'Dîroka Siyasî',
        nameTr: 'Siyasi Tarih',
        descriptionKu: 'Raman û bûyerên siyasî yên kevn',
        descriptionTr: 'Geçmişteki siyasi fikir ve olaylar',
      ),
      SubcategoryInfo(
        id: 'siyaseta_nujen',
        nameKu: 'Siyaseta Nûjen',
        nameTr: 'Modern Siyaset',
        descriptionKu: 'Siyaseta kurdî ya sedsala 21em',
        descriptionTr: '21. yüzyıl Kürt siyasi yapısı',
      ),
      SubcategoryInfo(
        id: 'tevger',
        nameKu: 'Tevgerên Civakî',
        nameTr: 'Toplumsal Hareketler',
        descriptionKu: 'Rêxistin û partiyên civakî',
        descriptionTr: 'Toplumsal örgüt ve partiler',
      ),
    ],
    'Paradigma': [
      SubcategoryInfo(
        id: 'demokratik',
        nameKu: 'Demokratîk',
        nameTr: 'Demokratik Konfederalizm',
        descriptionKu: 'Ramana neteweya demokratîk',
        descriptionTr: 'Demokratik ulus kuramı ve esasları',
      ),
      SubcategoryInfo(
        id: 'ekoloji',
        nameKu: 'Ekolojî',
        nameTr: 'Ekoloji',
        descriptionKu: 'Parastina xweza û jiyanê',
        descriptionTr: 'Doğa ve yaşamın korunması bilinci',
      ),
      SubcategoryInfo(
        id: 'jineoloji',
        nameKu: 'Jineolojî',
        nameTr: 'Jineoloji (Kadın Bilimi)',
        descriptionKu: 'Zanistiya jin û jiyanê',
        descriptionTr: 'Kadın ve yaşam bilimi çalışmaları',
      ),
    ],
    'Teknolojî': [
      SubcategoryInfo(
        id: 'bingehên_teknolojiyê',
        nameKu: 'Bingehên Teknolojiyê',
        nameTr: 'Teknoloji Temelleri',
        descriptionKu: 'Amûr, pergal û têgehên bingehîn',
        descriptionTr: 'Temel araçlar, sistemler ve kavramlar',
      ),
      SubcategoryInfo(
        id: 'programkirin',
        nameKu: 'Programkirin',
        nameTr: 'Programlama',
        descriptionKu: 'Zimanên kodkirinê û algorîtma',
        descriptionTr: 'Kodlama dilleri ve algoritmalar',
      ),
      SubcategoryInfo(
        id: 'dijital_internet',
        nameKu: 'Dîjîtal û Înternet',
        nameTr: 'Dijital ve İnternet',
        descriptionKu: 'Tor, protokol û ewlehiya dîjîtal',
        descriptionTr: 'Ağlar, protokoller ve dijital güvenlik',
      ),
    ],
    'Sînema': _sinemaSubcategories,
    'Sinema': _sinemaSubcategories,
  };

  static const List<SubcategoryInfo> _sinemaSubcategories = [
    SubcategoryInfo(
      id: 'filmen_kurdi',
      nameKu: 'Fîlm û Derhêner',
      nameTr: 'Filmler & Yönetmenler',
      descriptionKu: 'Fîlmên navdar û derhênerên kurdî',
      descriptionTr: 'Ünlü Kürt filmleri ve yönetmenleri',
    ),
    SubcategoryInfo(
      id: 'yilmaz_guney',
      nameKu: 'Yılmaz Güney û Klasîk',
      nameTr: 'Yılmaz Güney & Klasikler',
      descriptionKu: 'Sînema kevnar û berhemên nemir',
      descriptionTr: 'Sinema tarihi ve ölümsüz eserler',
    ),
    SubcategoryInfo(
      id: 'festival_belgefilm',
      nameKu: 'Belgefîlm û Festîval',
      nameTr: 'Belgesel & Festivaller',
      descriptionKu: 'Belgefîlm û festîvalên sînemayê',
      descriptionTr: 'Belgesel sinema ve festivaller',
    ),
  ];

  /// Alt kategori → konu anahtar kelimeleri. Eşleşme soru metni ve şıklar
  /// üzerinde yapılır; böylece "Rêziman" filtresi gerçekten dilbilgisi
  /// sorusu getirir.
  ///
  /// 2026-07-24 editoryal denetim: alt kategori `question.id.hashCode %
  /// listUzunluğu` ile atanıyordu. Yani "Dilbilgisi" filtresi rastgele
  /// sorular gösteriyordu — kullanıcıya verilen konu sözü sahteydi ve aynı
  /// soru, id değişmediği sürece yanlış konu altında sabit kalıyordu.
  static const Map<String, List<String>> _keywords = {
    // Ziman
    'reziman': [
      'rêziman',
      'lêker',
      'navdêr',
      'rengdêr',
      'cînav',
      'dem',
      'raweya',
      'pirjimar',
      'yekjimar',
      'izafe',
      'ezafe',
      'çêker',
      'hevok',
      'binavkirî',
      'nebinavkirî',
    ],
    'rastnivisin': [
      'rastnivîs',
      'tîp',
      'herf',
      'alfabe',
      'nivîsîn',
      'xal',
      'kîteyê',
      'kîte',
      'dengdêr',
      'dengdar',
    ],
    'peyvnasi': ['peyv', 'wate', 'hevwate', 'dijwate', 'bi tirkî', 'ferheng'],
    // Çand
    'cejn': ['newroz', 'cejn', 'eyd', 'roja', 'kevneşop', 'dawet', 'bûk'],
    'dastangotin': [
      'dastan',
      'mem û zîn',
      'siyabend',
      'kawa',
      'leheng',
      'efsane',
    ],
    'tistonek': ['tiştonek', 'mamik', 'bilmece', 'zekaya'],
    'folklor': [
      'folklor',
      'çîrok',
      'gotina pêşiyan',
      'govend',
      'reqs',
      'xwarin',
    ],
    // Dîrok
    'diroka_kevn': [
      'med',
      'mîtan',
      'hûrî',
      'kardûx',
      'gutî',
      'kevnar',
      'berî zayînê',
      'antîk',
    ],
    'sexsiyet': [
      'selahedîn',
      'ehmedê xanî',
      'bedirxan',
      'şêx',
      'seyid',
      'mîr',
      'kesayet',
    ],
    'diroka_nujen': [
      'sedsala',
      'peymana',
      'serhildan',
      'komar',
      'lozan',
      'dewlet',
    ],
    // Edebiyat
    'helbest': ['helbest', 'helbestvan', 'şiir', 'malbend', 'qafiye'],
    'klasik': [
      'klasîk',
      'melayê cizîrî',
      'feqiyê teyran',
      'elî herîrî',
      'dîwan',
    ],
    'roman': ['roman', 'çîroknivîs', 'nivîskar', 'pirtûk', 'kovar', 'weşan'],
    // Cografya
    'ciya_cem': [
      'çiya',
      'çem',
      'gol',
      'ava',
      'zagros',
      'agirî',
      'dîcle',
      'firat',
    ],
    'bajar_ci': ['bajar', 'bajarê', 'navend', 'gund', 'herêm'],
    'sinor_duma': [
      'sînor',
      'welat',
      'nexşe',
      'herêma',
      'başûr',
      'bakur',
      'rojava',
      'rojhilat',
    ],
    // Muzîk
    'dengbeji': ['dengbêj', 'stran', 'kilam', 'lawik', 'şeşbend'],
    'amur': ['amûr', 'tembûr', 'bilûr', 'def', 'zirne', 'saz', 'erbane'],
    'nujen': ['muzîka nûjen', 'komele', 'grûp', 'albûm', 'stranbêj'],
    // Siyaset
    'diroka_siyasi': ['dîroka siyasî', 'partî', 'tevgera netewî', 'serhildana'],
    'siyaseta_nujen': ['hilbijartin', 'parlamento', 'meclis', 'siyaseta nûjen'],
    'tevger': ['tevger', 'rêxistin', 'kongra', 'kjar', 'jineolojî', 'yekîtî'],
    // Paradigma
    'demokratik': [
      'konfederalîzm',
      'demokratîk',
      'komun',
      'xweseriya',
      'meclisa gel',
    ],
    'ekoloji': ['ekolojî', 'xweza', 'jîngeh', 'avhewa', 'çandinî'],
    'jineoloji': [
      'jineolojî',
      'jin',
      'azadiya jinê',
      'hevserok',
      'xwe-parastin',
    ],
    // Teknolojî
    'programkirin': ['program', 'kod', 'algorîtma', 'nivîsandina bernameyê'],
    'dijital_internet': ['înternet', 'tor', 'dîjîtal', 'ewlehî', 'protokol'],
    'bingehên_teknolojiyê': ['komputer', 'amûra', 'pergal', 'teknolojî'],
    // Sînema
    'filmen_kurdi': ['fîlm', 'derhêner', 'sînema', 'lîstikvan', 'senaryo'],
    'yilmaz_guney': ['yılmaz güney', 'rê', 'yol', 'sûr', 'dîwar', 'klasîk'],
    'festival_belgefilm': ['belgefîlm', 'festîval', 'xelat', 'sînematografî'],
  };

  /// Soruyu konusuna göre bir alt kategoriye eşler.
  ///
  /// Anahtar kelime eşleşmesi bulunamazsa, kategori içinde **dengeli
  /// dağıtım** için id türevli sabit bir indeks kullanılır. Bu, eski
  /// davranışın bilinçli olarak korunan tek parçasıdır: konusu belirsiz
  /// soru da bir yere düşmeli, yoksa alt kategori listesi boş kalır.
  static String getSubcategoryId(QuizQuestion question) {
    final list = subcategories[question.category];
    if (list == null || list.isEmpty) return '';
    final matched = _matchByKeyword(question, list);
    if (matched != null) return matched.id;
    return list[question.id.hashCode.abs() % list.length].id;
  }

  /// Soru için alt kategori etiketini döner.
  static String getSubcategoryLabel(QuizQuestion question, bool isKu) {
    final list = subcategories[question.category];
    if (list == null || list.isEmpty) return '';
    final matched =
        _matchByKeyword(question, list) ??
        list[question.id.hashCode.abs() % list.length];
    return isKu ? matched.nameKu : matched.nameTr;
  }

  static SubcategoryInfo? _matchByKeyword(
    QuizQuestion question,
    List<SubcategoryInfo> list,
  ) {
    final haystack = [
      question.prompt,
      ...question.answers,
    ].join(' ').toLowerCase();

    SubcategoryInfo? best;
    var bestScore = 0;
    for (final info in list) {
      final words = _keywords[info.id];
      if (words == null) continue;
      var score = 0;
      for (final word in words) {
        if (haystack.contains(word)) score++;
      }
      if (score > bestScore) {
        bestScore = score;
        best = info;
      }
    }
    return best;
  }
}
