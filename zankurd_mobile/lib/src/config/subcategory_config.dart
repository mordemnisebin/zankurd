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
  };

  /// Soru kimliğini stabil bir alt kategori id'sine eşler.
  static String getSubcategoryId(QuizQuestion question) {
    final list = subcategories[question.category];
    if (list == null || list.isEmpty) return '';
    final code = question.id.hashCode.abs();
    final index = code % list.length;
    return list[index].id;
  }

  /// Soru için alt kategori etiketini döner.
  static String getSubcategoryLabel(QuizQuestion question, bool isKu) {
    final list = subcategories[question.category];
    if (list == null || list.isEmpty) return '';
    final code = question.id.hashCode.abs();
    final index = code % list.length;
    return isKu ? list[index].nameKu : list[index].nameTr;
  }
}
