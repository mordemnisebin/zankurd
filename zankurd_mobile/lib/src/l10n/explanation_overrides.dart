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
  // ---- Edebiyat ----
  'offline_0649': ExplanationOverride(
    ku: 'Di edebiyata kurdî de "çîrok" çîroka kurt a pexşan e. Bûyer, karakter '
        'û peyamekê di forma kurt de digihîne; kevneşopiya devkî ya kurdî '
        'dewlemend e bi çîrokên gelêrî.',
    tr: 'Kürt edebiyatında "çîrok" kısa öykü/hikâye demektir. Olay, karakter ve '
        'bir mesajı kısa biçimde aktarır; Kürt sözlü geleneği halk '
        'hikâyeleriyle zengindir.',
  ),
  'offline_0654': ExplanationOverride(
    ku: 'Di edebiyata kurdî de "helbest" tê wateya şiîrê. Bi pîvan, kafiye û '
        'hestan ve girêdayî ye; helbestvanên klasîk wek Melayê Cizîrî û Ehmedê '
        'Xanî ev huner bilind kirine.',
    tr: 'Kürt edebiyatında "helbest" şiir anlamına gelir. Ölçü, kafiye ve '
        'duyguyla ilişkilidir; Melayê Cizîrî ve Ehmedê Xanî gibi klasik şairler '
        'bu sanatı yükseltmiştir.',
  ),
  'offline_0660': ExplanationOverride(
    ku: 'Di edebiyata kurdî de "destan" çîroka dirêj a qehremanî ye. Bûyerên '
        'mezin, şer û lehengan vedibêje; "Memê Alan" yek ji destanên navdar ên '
        'kurdî ye.',
    tr: 'Kürt edebiyatında "destan", kahramanlık anlatan uzun bir anlatıdır. '
        'Büyük olayları, savaşları ve kahramanları anlatır; "Memê Alan" ünlü '
        'Kürt destanlarından biridir.',
  ),
  'offline_0669': ExplanationOverride(
    ku: 'Di edebiyatê de "mecaz" wateya rast a peyvê nayê, wateyeke veguhêz '
        'bikar tîne. Wek gotina "şêr" ji bo mirovê wêrek; ji bo hêz û bandorê '
        'tê xebitandin.',
    tr: 'Edebiyatta "mecaz", bir sözcüğün gerçek anlamını değil aktarılmış '
        'anlamını kullanmaktır. "Aslan" sözünü yiğit biri için kullanmak gibi; '
        'anlatıma güç ve etki katar.',
  ),
  'offline_0672': ExplanationOverride(
    ku: 'Di helbestê de "kafiye" lihevhatina dengan e li dawiya rêzan. Awaz û '
        'ahenga şiîrê xurt dike û di bîra mirovan de hêsantir dimîne.',
    tr: 'Şiirde "kafiye", dize sonlarındaki ses uyumudur. Şiirin ahengini '
        'güçlendirir ve akılda kalmasını kolaylaştırır.',
  ),
  // ---- Muzîk ----
  'offline_0881': ExplanationOverride(
    ku: 'Di muzîka kurdî de "stran" tê wateya kilam/stranê. Dikare evînî, '
        'qehremanî an gelêrî be; dengbêj û hunermend wan ji nifşê re davêjin.',
    tr: 'Kürt müziğinde "stran" şarkı/türkü demektir. Aşk, kahramanlık ya da '
        'halk temalı olabilir; dengbêjler ve sanatçılar bunları kuşaklara '
        'aktarır.',
  ),
  'offline_0885': ExplanationOverride(
    ku: 'Di muzîka kurdî de "def" sazeke lêdanê ye (def/bendîr). Di govend û '
        'şahiyan de ritmê dide û pirî caran bi erbaneyê re tê xebitandin.',
    tr: 'Kürt müziğinde "def" vurmalı bir çalgıdır (bendir/tef). Halaylarda ve '
        'şenliklerde ritmi verir, çoğu zaman erbane ile birlikte kullanılır.',
  ),
  'offline_0889': ExplanationOverride(
    ku: 'Di muzîka kurdî de "erbane" sazeke lêdanê ya dor e (def a mezin). Di '
        'dawet û dîlanan de ritma bingehîn peyda dike.',
    tr: 'Kürt müziğinde "erbane", yuvarlak vurmalı bir çalgıdır (büyük tef). '
        'Düğün ve halaylarda temel ritmi sağlar.',
  ),
  'offline_0892': ExplanationOverride(
    ku: 'Di muzîka kurdî de "tembûr" sazeke bi têl e. Bi taybetî di muzîka olî '
        'û aşiqî de tê bikaranîn û dengê wê yê kûr navdar e.',
    tr: 'Kürt müziğinde "tembûr" telli bir çalgıdır. Özellikle dinî ve âşık '
        'müziğinde kullanılır ve derin tınısıyla bilinir.',
  ),
  // ---- Siyaset / Paradigma (nötr, terim/tanım odaklı) ----
  'offline_2290': ExplanationOverride(
    ku: '"Jin, Jiyan, Azadî" dirûşmeke navdar e; tê de "jin" tê wateya "kadın". '
        'Peyv bi "jiyan" (hayat) û "azadî" (özgürlük) re tê bikaranîn.',
    tr: '"Jin, Jiyan, Azadî" bilinen bir slogandır; buradaki "jin" Kürtçede '
        '"kadın" demektir. Söz "jiyan" (hayat) ve "azadî" (özgürlük) '
        'sözcükleriyle birlikte kullanılır.',
  ),
  'offline_2291': ExplanationOverride(
    ku: 'Peyva "azadî" di Kurmancî de tê wateya "özgürlük". Di gelek dirûşm û '
        'stranan de wek nirxeke bingehîn derbas dibe.',
    tr: '"Azadî" sözcüğü Kürtçede "özgürlük" anlamına gelir. Birçok slogan ve '
        'şarkıda temel bir değer olarak geçer.',
  ),
  'offline_2292': ExplanationOverride(
    ku: '"Jineolojî" wek "zanista jinê" tê pênasekirin; li dora zanîna jinê û '
        'rexneya baviksalariyê (patriyarka) ava dibe.',
    tr: '"Jineolojî" en kısa biçimde "kadın bilimi" olarak açıklanır; kadın '
        'bilgisi ve patriarka eleştirisi etrafında kurulan bir kavramdır.',
  ),
  'offline_2298': ExplanationOverride(
    ku: 'Peyva "hevaltî" tê wateya "yoldaşlık/arkadaşlık". Çanda hevaltiyê li '
        'ser hevgirtin û piştevaniya hevdû ava dibe.',
    tr: '"Hevaltî" sözcüğü "yoldaşlık/arkadaşlık" anlamına gelir. Hevaltî '
        'kültürü dayanışma ve karşılıklı destek üzerine kuruludur.',
  ),
  'offline_2326': ExplanationOverride(
    ku: 'Têgîna "konfederalîzma demokratîk" ji aliyê Abdullah Ocalan ve hatiye '
        'pêşxistin. Ev têgîn li ser demokrasiya herêmî, parastina jinê û '
        'ekolojiyê disekine.',
    tr: '"Demokratik konfederalizm" kavramı Abdullah Öcalan tarafından '
        'geliştirilmiştir. Yerel demokrasi, kadın özgürlüğü ve ekoloji '
        'vurgusuyla tanımlanan bir kavramdır.',
  ),
  'offline_2327': ExplanationOverride(
    ku: 'Wek alternatîfa "modernîteya kapîtalîst", têgîna "modernîteya '
        'demokratîk" tê pêşniyarkirin. Ew rexneya navend-dewlet û pergala '
        'kapîtalîst dike.',
    tr: '"Kapitalist modernite"ye alternatif olarak önerilen kavram '
        '"demokratik modernite"dir. Merkezî ulus-devlet ve kapitalist sisteme '
        'yönelik bir eleştiri içerir.',
  ),
  'offline_2282': ExplanationOverride(
    ku: 'Pergala "hevserokatî" nûnertiya wekhev a jin û mêr û birêvebirina '
        'hevpar kurumsal dike. Armanc wekheviya zayendî ye di rêvebirinê de.',
    tr: '"Eşbaşkanlık" sistemi kadın-erkek eşit temsili ve ortak yönetimi '
        'kurumsallaştırmayı hedefler. Amaç, yönetimde cinsiyet eşitliğidir.',
  ),
  'offline_2334': ExplanationOverride(
    ku: 'Daxwaza "xweseriya demokratîk" tê wateya ku civak karûbarên xwe yên '
        'herêmî bi xwe birêve bibin. Li ser xwe-birêvebirina herêmî disekine.',
    tr: '"Demokratik özerklik" talebi, toplulukların yerel işlerini '
        'kendilerinin yönetmesini ifade eder. Yerel öz-yönetim vurgusu taşır.',
  ),
  'offline_2335': ExplanationOverride(
    ku: 'Daxwaza "perwerdeya bi zimanê dayikê" dikeve kategoriya mafên çandî û '
        'zimanî. Parastina zimanê kêmaniyan armanc dike.',
    tr: '"Anadilde eğitim" talebi, kültürel ve dilsel haklar kategorisine '
        'girer. Azınlık dillerinin korunmasını hedefler.',
  ),
};
