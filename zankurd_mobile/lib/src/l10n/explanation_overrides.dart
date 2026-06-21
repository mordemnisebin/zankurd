/// Elle yazılmış, öğretici açıklamalar. Soru id'sine göre anahtarlanır ve
/// şablon-üretimi açıklamalardan (explanation_ku.dart) önceliklidir.
///
/// Amaç: kuru "X = Y" karşılığı yerine, bağlam ve kültürel/tarihî bilgi veren
/// 2-3 cümlelik gerçek açıklamalar sunmak. Kademeli olarak genişletilecek.
library;

class ExplanationOverride {
  const ExplanationOverride({required this.ku, required this.tr});

  final String ku;
  final String tr;
}

/// Soru id → elle yazılmış açıklama.
const Map<String, ExplanationOverride> explanationOverrides = {
  // ---- Çand (Kültür) ----
  'offline_0376': ExplanationOverride(
    ku: 'Newroz cejna hatina biharê ye ku di 21ê Adarê de tê pîrozkirin û '
        'nûbûna xwezayê temsîl dike. Di çanda kurdî de bi efsaneya Dehak û '
        'Kawayê Hesinkar re tê girêdan û bûye sembola azadî û berxwedanê.',
    tr: 'Newroz, 21 Mart\'ta kutlanan ve baharın gelişini, doğanın yeniden '
        'canlanmasını simgeleyen bir bayramdır. Kürt kültüründe Dehak ile '
        'Demirci Kawa efsanesine bağlanarak özgürlük ve direnişin sembolü '
        'olmuştur.',
  ),
  'offline_0381': ExplanationOverride(
    ku: 'Govend dîlana bi destê hev girtî ye ku bi komî tê gotin. Di dawet û '
        'şahiyan de yekîtî û hevgirtina civakê nîşan dide.',
    tr: 'Govend, el ele tutuşarak oynanan toplu bir halk oyunudur (halay). '
        'Düğün ve kutlamalarda topluluğun birlik ve dayanışmasını ifade eder.',
  ),
  'offline_0386': ExplanationOverride(
    ku: 'Dengbêj hunermendê çanda devkî ya kurdî ye ku bi awaz çîrokan '
        'vedibêje. Bûyerên dîrokî, evîn û êşan bi "kilam"an ji nifşekê re '
        'davêje nifşê din.',
    tr: 'Dengbêj, Kürt sözlü kültüründe ezgiyle hikâye anlatan halk '
        'sanatçısıdır. Tarihî olayları, aşkları ve acıları "kilam" denen uzun '
        'ezgilerle kuşaktan kuşağa aktarır.',
  ),
  // ---- Dîrok (Tarih) ----
  'offline_2081': ExplanationOverride(
    ku: 'Navenda Mîrgeha Botanê bajarê Cizîrê bû. Di sedsala 19an de di bin '
        'serokatiya Mîr Bedirxan de bûye mîrgeheke kurdî ya bihêz û '
        'nîv-xweser.',
    tr: 'Botan Mîrliği\'nin merkezi Cizre (Cizîr) şehriydi. 19. yüzyılda Mîr '
        'Bedirxan önderliğinde güçlü ve yarı-özerk bir Kürt beyliği olmuştur.',
  ),
  'offline_2082': ExplanationOverride(
    ku: 'Mîr Bedirxan mîrê Mîrgeha Botanê bû. Serhildana wî ya 1847an wek '
        'berxwedaneke girîng a kurdî li dijî Osmaniyan di dîrokê de cih '
        'girtiye.',
    tr: 'Mîr Bedirxan, Botan Mîrliği\'nin beyiydi. 1847\'deki ayaklanması '
        'Osmanlı\'ya karşı önemli bir Kürt direnişi olarak tarihe geçmiştir.',
  ),
  'offline_2083': ExplanationOverride(
    ku: 'Qesra Îshaq Paşa li nêzîkî bajarê Bazîd (Doğubayazıt) e. Ev qesra ku '
        'di sedsala 18an de hatî temamkirin, bandora mîmariya Osmanî, Selçûkî '
        'û herêmî dihewîne.',
    tr: 'İshak Paşa Sarayı, Doğubayazıt (Bazîd) yakınlarındadır. 18. yüzyılda '
        'tamamlanan saray; Osmanlı, Selçuklu ve yerel mimarinin etkilerini '
        'taşıyan görkemli bir yapıdır.',
  ),
  'offline_2086': ExplanationOverride(
    ku: 'Pira Malabadî li ser Çemê Batmanê ye. Ev pira ku di sedsala 12an de '
        'di dema Artuqiyan de hatî çêkirin, xwedî yek ji kemerên kevirî yên '
        'herî fireh ên cîhanê ye.',
    tr: 'Malabadi Köprüsü, Batman Çayı üzerindedir. 12. yüzyılda Artuklular '
        'döneminde yapılan köprü, dünyanın en geniş taş kemerlerinden birine '
        'sahiptir.',
  ),
  'offline_2087': ExplanationOverride(
    ku: 'Şerefname di sala 1597an de ji aliyê Şerefxanê Bedlîsî ve hatiye '
        'nivîsîn. Wek yek ji çavkaniyên yekem ên berfireh ên dîroka kurdî tê '
        'hesibandin.',
    tr: 'Şerefname\'yi 1597\'de Bitlisli Şeref Han (Şerefxanê Bedlîsî) '
        'yazmıştır. Kürt tarihinin ilk kapsamlı yazılı kaynaklarından biri '
        'kabul edilir.',
  ),
  // ---- Cografya ----
  'offline_2141': ExplanationOverride(
    ku: 'Çiyayê herî bilind ê Tirkiyeyê Çiyayê Agirî ye. Ev çiyayê ku li '
        'rojhilatê Anatoliyê ye, volkaneke vemirî ye.',
    tr: 'Türkiye\'nin en yüksek dağı Ağrı Dağı\'dır (Çiyayê Agirî). Doğu '
        'Anadolu\'da yer alan dağ, sönmüş bir yanardağdır.',
  ),
  'offline_2142': ExplanationOverride(
    ku: 'Bilindahiya Çiyayê Agirî nêzîkî 5.137 metre ye; ev wê dike lûtkeya '
        'herî bilind a Tirkiyeyê.',
    tr: 'Ağrı Dağı\'nın yüksekliği yaklaşık 5.137 metredir; bu da onu '
        'Türkiye\'nin en yüksek zirvesi yapar.',
  ),
  'offline_2143': ExplanationOverride(
    ku: 'Gola herî mezin a Tirkiyeyê Gola Wanê ye. Bi ava xwe ya sodayî '
        '(xwêyî) tê naskirin û hewzeke girtî ye.',
    tr: 'Türkiye\'nin en büyük gölü Van Gölü\'dür (Gola Wanê). Sodalı (tuzlu) '
        'yapısıyla bilinen kapalı bir havzadır.',
  ),
  'offline_2145': ExplanationOverride(
    ku: 'Çemê Dîcle di bajarê Amedê (Diyarbakır) re derbas dibe. Yek ji du '
        'çemên mezin ên Mezopotamyayê ye.',
    tr: 'Dicle Nehri (Çemê Dîcle), Diyarbakır (Amed) şehrinden geçer. '
        'Mezopotamya\'nın iki büyük nehrinden biridir.',
  ),
  'offline_2146': ExplanationOverride(
    ku: 'Du çemên mezin ên Mezopotamyayê Dîcle û Ferat in. Navê "Mezopotamya" '
        'bi yewnanî tê wateya "navbera du çeman".',
    tr: 'Mezopotamya\'nın iki büyük nehri Dicle ve Fırat\'tır (Dîcle û Ferat). '
        '"Mezopotamya" adı Yunanca "iki nehir arası" anlamına gelir.',
  ),
  'offline_2148': ExplanationOverride(
    ku: 'Hewlêr paytexta Herêma Kurdistanê ya Iraqê ye. Bi keleha xwe ya '
        'dîrokî navdar e ku wek yek ji bajarên herî kevn ên cîhanê tê '
        'hesibandin.',
    tr: 'Hewlêr (Erbil), Irak Kürdistan Bölgesi\'nin başkentidir. Dünyanın '
        'kesintisiz yerleşilen en eski şehirlerinden sayılan tarihî kalesiyle '
        'ünlüdür.',
  ),
  'offline_2149': ExplanationOverride(
    ku: 'Silêmanî bajarekî kurdî ye li Iraqê. Bi navenda çand û edebiyatê bûna '
        'xwe tê naskirin.',
    tr: 'Süleymaniye (Silêmanî), Irak\'ta yer alan bir Kürt şehridir. Kültür '
        've edebiyat merkezi olmasıyla tanınır.',
  ),
  'offline_2150': ExplanationOverride(
    ku: 'Gola Urmiyê li Îranê ye. Berê gola herî mezin a Îranê bû; di salên '
        'dawî de bi pirranî ziwa bûye.',
    tr: 'Urmiye Gölü (Gola Urmiyê), İran\'da yer alır. İran\'ın en büyük '
        'gölüydü; son yıllarda büyük ölçüde kurumuştur.',
  ),
};
