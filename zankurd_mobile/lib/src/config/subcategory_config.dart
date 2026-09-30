import '../models/quiz_question.dart';
import 'category_visuals.dart';

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
    // 2026-09-30: kategori "Bilim ve Düşünce / Zanist û Raman" adıyla
    // sunulur (iç kimlik 'Paradigma' kalır). Tek bir hareketin öğretisini
    // anlatan sorular emekli edildi; kalan nötr toplum bilimi / felsefe
    // soruları ile genel bilim (atom, sağlık, doğa) üç konuya bölünür.
    'Paradigma': [
      SubcategoryInfo(
        id: 'civak_maf',
        nameKu: 'Civak û Maf',
        nameTr: 'Toplum ve Haklar',
        descriptionKu: 'Demokrasî, maf û jiyana hevpar',
        descriptionTr: 'Demokrasi, haklar ve ortak yaşam',
      ),
      SubcategoryInfo(
        id: 'raman_felsefe',
        nameKu: 'Raman û Felsefe',
        nameTr: 'Felsefe ve Düşünce',
        descriptionKu: 'Ramanên mezin, nirx û têgeh',
        descriptionTr: 'Büyük fikirler, değerler ve kavramlar',
      ),
      SubcategoryInfo(
        id: 'zanist_jiyan',
        nameKu: 'Zanist û Jiyan',
        nameTr: 'Bilim ve Yaşam',
        descriptionKu: 'Xweza, tenduristî û teknolojî',
        descriptionTr: 'Doğa, sağlık ve teknoloji',
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
    // 2026-09-30: Kürtlerle doğrudan bağı olmayan nötr genel bilgi. Üç konu
    // "ne sorulursa" değil, bankadaki gerçek sorulara göre kuruldu: dünya
    // sineması (yönetmen, film, festival), dünya coğrafyası (okyanus,
    // parçalar, başkentler, harita kavramları) ve geriye kalan tarih,
    // dünya edebiyatı, klasik müzik ve genel kültür.
    'Cîhan': _cihanSubcategories,
  };

  /// Kategori adını — takma ad olsa bile — alt kategori listesine çevirir.
  ///
  /// `CategoryVisuals` on bir takma ad tanır ('Dil'→'Ziman', 'Tarih'→'Dîrok',
  /// 'Film'→'Sînema', …) çünkü kategori adı her zaman kanonik biçimde
  /// gelmiyor. Bu haritada anahtarlar YALNIZ kanonik biçimdir; ham `[]`
  /// erişimi bir takma adla çağrıldığında sessizce `null` döner ve çağıran
  /// alt kategoriyi hiç yokmuş gibi ele alır — hata yok, yalnız kaybolmuş
  /// bir başlık.
  ///
  /// Bu tam olarak bir kez yaşandı ve tek vakalık yamalandı: haritada
  /// `'Sînema'` ile birebir aynı listeyi taşıyan ikinci bir `'Sinema'`
  /// anahtarı duruyordu. Yama yalnız o takma adı kurtarıyor, kalan onunu
  /// bırakıyordu. Çözüm kopya anahtar değil, kanonikleştiren tek bir
  /// erişimci: çağıranın takma adı düşünmesi gerekmiyor (2026-08-17).
  static List<SubcategoryInfo> forCategory(String category) =>
      subcategories[category] ??
      subcategories[CategoryVisuals.canonicalName(category)] ??
      const [];

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

  static const List<SubcategoryInfo> _cihanSubcategories = [
    SubcategoryInfo(
      id: 'sinema_cihan',
      nameKu: 'Sînemaya Cîhanê',
      nameTr: 'Dünya Sineması',
      descriptionKu: 'Fîlm, derhêner û festîvalên cîhanê',
      descriptionTr: 'Dünya filmleri, yönetmenleri ve festivalleri',
    ),
    SubcategoryInfo(
      id: 'erdnigari_cihan',
      nameKu: 'Erdnîgariya Cîhanê',
      nameTr: 'Dünya Coğrafyası',
      descriptionKu: 'Okyanûs, parzemîn, paytext û nexşe',
      descriptionTr: 'Okyanuslar, kıtalar, başkentler ve haritalar',
    ),
    SubcategoryInfo(
      id: 'dirok_gisti',
      nameKu: 'Dîrok û Zanyariya Giştî',
      nameTr: 'Tarih ve Genel Kültür',
      descriptionKu: 'Dîrok, wêje û muzîka cîhanê',
      descriptionTr: 'Dünya tarihi, edebiyatı ve müziği',
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
      // Kurmancîde yaygın biçim "destan"dır. Yalın "destan" kullanılamaz:
      // "el" (dest) kelimesinin çoğuluyla aynıdır ("bi hevgirtina destan"
      // = el ele tutuşarak); izafeli "destana ..." yalnız destanı anlatır.
      'destana',
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
      // Klasik soruların çoğu bu adları yalnız ÇELDİRİCİDE taşıyordu;
      // eşleştirme artık çeldiriciye bakmadığı için klasik eserin ve
      // şairin kendisi anahtar kelimedir.
      'ehmedê xanî',
      'mem û zîn',
      'nûbihar',
      'melayê bateyî',
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
    // Paradigma (Bilim ve Düşünce). Eşleşme yalnız soru metni + doğru
    // cevap üzerinde, Kurmancî yazımla yapılır; eşit puanda listedeki ilk
    // konu kazanır (civak_maf > raman_felsefe > zanist_jiyan).
    'civak_maf': [
      'demokrasi',
      'demokratîk',
      'konfederalîzm',
      'hemwelatî',
      'sivîl',
      'desthilat',
      'veqetandina hêzan',
      'dadperweriya',
      'hevgirtin',
      'pirrengî',
      'nasname',
      'xwe-rêxistin',
      'maf',
    ],
    'raman_felsefe': [
      'utopya',
      'lîberalîzm',
      'anarşîzm',
      'marksîst',
      'kapîtalîzm',
      'femînîzm',
      'patriyarka',
      'zayend',
      'jineolojî',
      'felsefe',
      'etîk',
      'exlaq',
      'nirx',
      'paradîgma',
      'raman',
      'rexne',
      'têgeh',
    ],
    'zanist_jiyan': [
      'zanist',
      'xweza',
      'ekolojî',
      'jîngeh',
      'avhewa',
      'çandin',
      'şoreşa neolîtîk',
      'atom',
      'element',
      'kîmya',
      'fîzîk',
      'bîyolojî',
      'tenduristî',
      'nexweş',
      'vîtamîn',
      'teknolojî',
      'enerjî',
    ],
    // Teknolojî
    'programkirin': ['program', 'kod', 'algorîtma', 'nivîsandina bernameyê'],
    'dijital_internet': ['înternet', 'tor', 'dîjîtal', 'ewlehî', 'protokol'],
    'bingehên_teknolojiyê': ['komputer', 'amûra', 'pergal', 'teknolojî'],
    // Sînema
    'filmen_kurdi': ['fîlm', 'derhêner', 'sînema', 'lîstikvan', 'senaryo'],
    // Cîhan (2026-09-30). Eşleşme yalnız soru metni + doğru cevapta, alt dize
    // olarak yapılır (bkz. `_matchByKeyword`); bu yüzden «welat» gibi çok
    // yerde geçen kökler bilerek YOK: «kîjan welatî de ji dayik bûye» her
    // kişi sorusunu coğrafyaya çekerdi. Eşit puanda listedeki ilk konu
    // kazanır (sinema_cihan > erdnigari_cihan > dirok_gisti); üçüncü konu
    // tarih, dünya edebiyatı, klasik müzik ve genel kültürün toplandığı
    // kalan konudur.
    'sinema_cihan': [
      'fîlm',
      'derhêner',
      'sînema',
      'oscar',
      'festîval',
      'edîsyon',
      'montaj',
      'anîmasyon',
      'studyo',
      'biennale',
      'jûriya',
    ],
    'erdnigari_cihan': [
      'okyanûs',
      'parzemîn',
      'paytext',
      'nexşe',
      'koordînat',
      'projeksiyon',
      'azîmût',
      'bajarvanî',
      'koçberiy',
      'penaberî',
      'nifûs',
      'gerstêrk',
      'atmosfer',
      'ava şêrîn',
      'challenger',
      'heyv',
    ],
    'dirok_gisti': [
      'dîrok',
      'împaratorî',
      'sedsal',
      'şer',
      'şoreş',
      'sumer',
      'babîl',
      'mezopotamya',
      'akkad',
      'riya îpekê',
      'gerok',
      'roman',
      'destan',
      'çîrok',
      'fabl',
      'nobel',
      'nivîskar',
      'muzîk',
      'bestekar',
      'opera',
      'senfoni',
      'orkestra',
      'jazz',
      'blues',
      'mozart',
      'beethoven',
      'haydn',
      'amûr',
      'têgîn',
      'têgeha',
    ],
    // "rê" çıkarıldı: iki harflik alt dize "berê", "rêz", "rasterast"
    // gibi yüzlerce kelimede geçiyor ve çekim tekniği sorularını bu alt
    // kategoriye çekiyordu. Güney'in filmleri özgün adlarıyla aranır.
    //
    // Ad iki yazımla aranır. Kurmancî alfabede ı ve ü yoktur; banka Kurmancî
    // cümlede adı "Yilmaz Guney" diye yazar (2026-09-28'de beş soru). Liste
    // yalnız Türkçe yazımı tanıdığı için bu beş soru Güney hakkında olduğu
    // hâlde "Kürt filmleri"ne ya da genel havuza düşüyordu.
    'yilmaz_guney': [
      'yılmaz güney',
      'yilmaz guney',
      'güney',
      'guney',
      'yol',
      'sûr',
      'dîwar',
      'klasîk',
      'umut',
      'sürü',
      'endişe',
      'düşman',
      'duvar',
    ],
    'festival_belgefilm': ['belgefîlm', 'festîval', 'xelat', 'sînematografî'],
  };

  /// Soruyu konusuna göre bir alt kategoriye eşler.
  ///
  /// 2026-09-28 içerik dürüstlüğü düzeltmesi: anahtar kelime eşleşmesi
  /// bulunamazsa artık `id.hashCode % listUzunluğu` ile RASTGELE bir alt
  /// kategoriye düşürülmüyor. Bu eski davranış "dengeli dağıtım" diye
  /// yorumlanmıştı ama gerçekte sahte bir konu sözüydü: "Dîroka Kevn"
  /// filtresi id'nin hash'ine göre bir "Dîroka Nûjen" sorusunu da
  /// gösterebiliyordu, kullanıcı seçtiği konunun tam tersini okuyordu.
  /// Ölçüm (oynanabilir banka, 2026-09-28): Dîrok'un 157 sorusunun 48'i
  /// hiçbir anahtar kelimeyle eşleşmiyor ve böyle rastgele yerleşiyordu.
  ///
  /// Eşleşme yoksa boş dize döner: soru hiçbir alt kategoriye ait
  /// OLMADIĞINI açıkça söyler ve kategori genelindeki soru havuzunda kalır
  /// (bkz. `MockZanKurdRepository.loadLevelQuestions` — genel sorular alt
  /// kategori havuzunu tamamlamak için kullanılır, ama hiçbir alt
  /// kategoriye "ait" gösterilmez).
  static String getSubcategoryId(QuizQuestion question) {
    final list = subcategories[question.category];
    if (list == null || list.isEmpty) return '';
    return _matchByKeyword(question, list)?.id ?? '';
  }

  /// Soru için alt kategori etiketini döner; eşleşme yoksa ''.
  ///
  /// Rastgele bir başlık uydurmak [getSubcategoryId] ile aynı hataya
  /// düşer: konusu belirsiz bir soruya "Şexsiyetên Dîrokî" gibi somut bir
  /// etiket yapıştırmak, o etiketin altına hiç ait olmadığı bir soru
  /// koymaktır. Boş etiket "bu sorunun belirli bir alt konusu yok" der —
  /// bu, yanlış bir konu iddiasından daha dürüsttür.
  static String getSubcategoryLabel(QuizQuestion question, bool isKu) {
    final list = subcategories[question.category];
    if (list == null || list.isEmpty) return '';
    final matched = _matchByKeyword(question, list);
    if (matched == null) return '';
    return isKu ? matched.nameKu : matched.nameTr;
  }

  /// Bir alt kategorinin oynanabilirlik kartında görünmesi için gereken
  /// asgari anahtar-kelime-eşleşmeli soru sayısı.
  ///
  /// 20 = ilk iki seviyenin (Destpêk + Bingeh, her biri 10 soru) GERÇEK
  /// eşleşen sorularla doldurulabilmesi için gereken taban. Bunun altında
  /// kalan bir alt kategori kartı ("10 soru" vaadi) kendi konusundan değil
  /// komşu alt kategorilerden ya da genel havuzdan doldurulurdu — kart
  /// somut bir konu vaat eder, o vaadi tutamayan kategori hiç gösterilmez.
  static const int kMinSubcategoryQuestions = 20;

  /// Bir kategorinin, verilen oynanabilir soru havuzunda GERÇEKTEN yeterli
  /// içeriği olan alt kategorilerini yapılandırma sırasıyla döner.
  ///
  /// "Yeterli" = kategorideki [playable] sorular arasında bu alt kategoriye
  /// anahtar kelimeyle eşleşen sayı >= [kMinSubcategoryQuestions]. Saf bir
  /// fonksiyondur (yan etkisi yok); `SubcategoryScreen` onu seviye
  /// yükleyicisinin kullandığı AYNI havuzla (`playableQuestions`) çağırır —
  /// ayrı havuz kullanılsaydı ekran bir kart gösterir, seviye yükleyici o
  /// alt kategoride eşleşen soru bulamazdı.
  ///
  /// İçeriği bugün az olan bir alt kategori (ör. Muzîk › Muzîka Nûjen)
  /// burada gizlenir ama kalıcı biçimde değil: banka büyüyüp eşiği
  /// aştığında aynı kod aynı alt kategoriyi otomatik gösterir — sorusu
  /// yetince kendiliğinden görünür. Gizleme listesi elle tutulmaz.
  static List<SubcategoryInfo> visibleFor(
    String category,
    Iterable<QuizQuestion> playable,
  ) {
    final list = forCategory(category);
    if (list.isEmpty) return const [];
    final canonical = CategoryVisuals.canonicalName(category);
    final counts = <String, int>{};
    for (final question in playable) {
      if (CategoryVisuals.canonicalName(question.category) != canonical) {
        continue;
      }
      final id = getSubcategoryId(question);
      if (id.isEmpty) continue;
      counts[id] = (counts[id] ?? 0) + 1;
    }
    return list
        .where((info) => (counts[info.id] ?? 0) >= kMinSubcategoryQuestions)
        .toList(growable: false);
  }

  static SubcategoryInfo? _matchByKeyword(
    QuizQuestion question,
    List<SubcategoryInfo> list,
  ) {
    // Yalnız soru metni ve DOĞRU cevap aranır; çeldiriciler aranmaz.
    // Çeldirici çoğu zaman başka bir alt konudan seçilir: bir halay
    // sorusunun çeldiricisi "Destana Memê Alan" olunca soru destanlara,
    // bir ritim sorusunun çeldiricisinde "stran" geçince dengbêjliğe
    // düşüyordu (2026-09-28 ölçümü: 150'yi aşkın soru yalnız bir
    // çeldirici yüzünden bir alt kategoriye yazılmıştı).
    final haystack = [
      question.prompt,
      question.correctAnswer,
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
