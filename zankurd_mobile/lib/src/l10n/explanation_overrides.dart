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
    ku:
        'Newroz cejna hatina biharê ye ku di 21ê Adarê de tê pîrozkirin û '
        'nûbûna xwezayê temsîl dike. Di çanda kurdî de bi efsaneya Dehak û '
        'Kawayê Hesinkar re tê girêdan û bûye sembola azadî û berxwedanê.',
    tr:
        'Newroz, 21 Mart\'ta kutlanan ve baharın gelişini, doğanın yeniden '
        'canlanmasını simgeleyen bir bayramdır. Kürt kültüründe Dehak ile '
        'Demirci Kawa efsanesine bağlanarak özgürlük ve direnişin sembolü '
        'olmuştur.',
  ),
  'offline_0381': ExplanationOverride(
    ku:
        'Govend dîlana bi destê hev girtî ye ku bi komî tê gotin. Di dawet û '
        'şahiyan de yekîtî û hevgirtina civakê nîşan dide.',
    tr:
        'Govend, el ele tutuşarak oynanan toplu bir halk oyunudur (halay). '
        'Düğün ve kutlamalarda topluluğun birlik ve dayanışmasını ifade eder.',
  ),
  'offline_0386': ExplanationOverride(
    ku:
        'Dengbêj hunermendê çanda devkî ya kurdî ye ku bi awaz çîrokan '
        'vedibêje. Bûyerên dîrokî, evîn û êşan bi "kilam"an ji nifşekê re '
        'davêje nifşê din.',
    tr:
        'Dengbêj, Kürt sözlü kültüründe ezgiyle hikâye anlatan halk '
        'sanatçısıdır. Tarihî olayları, aşkları ve acıları "kilam" denen uzun '
        'ezgilerle kuşaktan kuşağa aktarır.',
  ),
  // ---- Dîrok (Tarih) ----
  'offline_2081': ExplanationOverride(
    ku:
        'Navenda Mîrgeha Botanê bajarê Cizîrê bû. Di sedsala 19an de di bin '
        'serokatiya Mîr Bedirxan de bûye mîrgeheke kurdî ya bihêz û '
        'nîv-xweser.',
    tr:
        'Botan Mîrliği\'nin merkezi Cizre (Cizîr) şehriydi. 19. yüzyılda Mîr '
        'Bedirxan önderliğinde güçlü ve yarı-özerk bir Kürt beyliği olmuştur.',
  ),
  'offline_2082': ExplanationOverride(
    ku:
        'Mîr Bedirxan mîrê Mîrgeha Botanê bû. Serhildana wî ya 1847an wek '
        'berxwedaneke girîng a kurdî li dijî Osmaniyan di dîrokê de cih '
        'girtiye.',
    tr:
        'Mîr Bedirxan, Botan Mîrliği\'nin beyiydi. 1847\'deki ayaklanması '
        'Osmanlı\'ya karşı önemli bir Kürt direnişi olarak tarihe geçmiştir.',
  ),
  'offline_2083': ExplanationOverride(
    ku:
        'Qesra Îshaq Paşa li nêzîkî bajarê Bazîd (Doğubayazıt) e. Ev qesra ku '
        'di sedsala 18an de hatî temamkirin, bandora mîmariya Osmanî, Selçûkî '
        'û herêmî dihewîne.',
    tr:
        'İshak Paşa Sarayı, Doğubayazıt (Bazîd) yakınlarındadır. 18. yüzyılda '
        'tamamlanan saray; Osmanlı, Selçuklu ve yerel mimarinin etkilerini '
        'taşıyan görkemli bir yapıdır.',
  ),
  'offline_2086': ExplanationOverride(
    ku:
        'Pira Malabadî li ser Çemê Batmanê ye. Ev pira ku di sedsala 12an de '
        'di dema Artuqiyan de hatî çêkirin, xwedî yek ji kemerên kevirî yên '
        'herî fireh ên cîhanê ye.',
    tr:
        'Malabadi Köprüsü, Batman Çayı üzerindedir. 12. yüzyılda Artuklular '
        'döneminde yapılan köprü, dünyanın en geniş taş kemerlerinden birine '
        'sahiptir.',
  ),
  'offline_2087': ExplanationOverride(
    ku:
        'Şerefname di sala 1597an de ji aliyê Şerefxanê Bedlîsî ve hatiye '
        'nivîsîn. Wek yek ji çavkaniyên yekem ên berfireh ên dîroka kurdî tê '
        'hesibandin.',
    tr:
        'Şerefname\'yi 1597\'de Bitlisli Şeref Han (Şerefxanê Bedlîsî) '
        'yazmıştır. Kürt tarihinin ilk kapsamlı yazılı kaynaklarından biri '
        'kabul edilir.',
  ),
  // ---- Cografya ----
  'offline_2141': ExplanationOverride(
    ku:
        'Çiyayê herî bilind ê Tirkiyeyê Çiyayê Agirî ye. Ev çiyayê ku li '
        'rojhilatê Anatoliyê ye, volkaneke vemirî ye.',
    tr:
        'Türkiye\'nin en yüksek dağı Ağrı Dağı\'dır (Çiyayê Agirî). Doğu '
        'Anadolu\'da yer alan dağ, sönmüş bir yanardağdır.',
  ),
  'offline_2142': ExplanationOverride(
    ku:
        'Bilindahiya Çiyayê Agirî nêzîkî 5.137 metre ye; ev wê dike lûtkeya '
        'herî bilind a Tirkiyeyê.',
    tr:
        'Ağrı Dağı\'nın yüksekliği yaklaşık 5.137 metredir; bu da onu '
        'Türkiye\'nin en yüksek zirvesi yapar.',
  ),
  'offline_2143': ExplanationOverride(
    ku:
        'Gola herî mezin a Tirkiyeyê Gola Wanê ye. Bi ava xwe ya sodayî '
        '(xwêyî) tê naskirin û hewzeke girtî ye.',
    tr:
        'Türkiye\'nin en büyük gölü Van Gölü\'dür (Gola Wanê). Sodalı (tuzlu) '
        'yapısıyla bilinen kapalı bir havzadır.',
  ),
  'offline_2145': ExplanationOverride(
    ku:
        'Çemê Dîcle di bajarê Amedê (Diyarbakır) re derbas dibe. Yek ji du '
        'çemên mezin ên Mezopotamyayê ye.',
    tr:
        'Dicle Nehri (Çemê Dîcle), Diyarbakır (Amed) şehrinden geçer. '
        'Mezopotamya\'nın iki büyük nehrinden biridir.',
  ),
  'offline_2146': ExplanationOverride(
    ku:
        'Du çemên mezin ên Mezopotamyayê Dîcle û Ferat in. Navê "Mezopotamya" '
        'bi yewnanî tê wateya "navbera du çeman".',
    tr:
        'Mezopotamya\'nın iki büyük nehri Dicle ve Fırat\'tır (Dîcle û Ferat). '
        '"Mezopotamya" adı Yunanca "iki nehir arası" anlamına gelir.',
  ),
  'offline_2148': ExplanationOverride(
    ku:
        'Hewlêr paytexta Herêma Kurdistanê ya Iraqê ye. Bi keleha xwe ya '
        'dîrokî navdar e ku wek yek ji bajarên herî kevn ên cîhanê tê '
        'hesibandin.',
    tr:
        'Hewlêr (Erbil), Irak Kürdistan Bölgesi\'nin başkentidir. Dünyanın '
        'kesintisiz yerleşilen en eski şehirlerinden sayılan tarihî kalesiyle '
        'ünlüdür.',
  ),
  'offline_2149': ExplanationOverride(
    ku:
        'Silêmanî bajarekî kurdî ye li Iraqê. Bi navenda çand û edebiyatê bûna '
        'xwe tê naskirin.',
    tr:
        'Süleymaniye (Silêmanî), Irak\'ta yer alan bir Kürt şehridir. Kültür '
        've edebiyat merkezi olmasıyla tanınır.',
  ),
  'offline_2150': ExplanationOverride(
    ku:
        'Gola Urmiyê li Îranê ye. Berê gola herî mezin a Îranê bû; di salên '
        'dawî de bi pirranî ziwa bûye.',
    tr:
        'Urmiye Gölü (Gola Urmiyê), İran\'da yer alır. İran\'ın en büyük '
        'gölüydü; son yıllarda büyük ölçüde kurumuştur.',
  ),
  // ---- Dîrok (bajar, mîrgeh û şaristaniyên kurdî) ----
  'offline_2084': ExplanationOverride(
    ku:
        'Sûrên Amedê bi dirêjahiya xwe ya nêzîkî 5,8 kîlometreyan tên '
        'hesibandin yek ji sûrên herî dirêj ên cîhanê, piştî Sûra Mezin a '
        'Çînê.',
    tr:
        'Diyarbakır Surları yaklaşık 5,8 kilometre uzunluğuyla, Çin Seddi\'nin '
        'ardından dünyanın en uzun sur duvarlarından biri kabul edilir.',
  ),
  'offline_2085': ExplanationOverride(
    ku:
        'Sûrên Amedê û Baxçeyên Hevselê di sala 2015an de ketin lîsteya '
        'Mîrateya Cîhanê ya UNESCOyê, wek "Peyzajeke Çandî".',
    tr:
        'Diyarbakır Surları ve Hevsel Bahçeleri, 2015\'te "Kültürel Peyzaj" '
        'kategorisinde UNESCO Dünya Mirası listesine girmiştir.',
  ),
  'offline_2088': ExplanationOverride(
    ku:
        'Şerefname yekem çavkaniya berfireh e ku dîrok û binemalên '
        'mîrgehên kurdî bi awayekî sîstematîk vedibêje; ji ber vê yekê wek '
        'belgeya bingehîn a dîroknasiya kurdî tê binavkirin.',
    tr:
        'Şerefname, Kürt beyliklerinin tarihini ve soy kütüğünü sistematik '
        'biçimde ele alan ilk kapsamlı kaynaktır; bu nedenle Kürt tarihçiliğinin '
        'temel belgesi sayılır.',
  ),
  'offline_2089': ExplanationOverride(
    ku:
        'Selahedînê Eyûbî li Tikrîtê ji dayik bûye û piştî Şerê Hîttînê '
        'Qudis ji Xaçperestan girt (1187); ev bûyer bandoreke mezin li ser '
        'dîroka Rojhilata Navîn hiştiye.',
    tr:
        'Kürt kökenli Selahaddin Eyyubi, Tikrit doğumludur ve Hıttin '
        'Savaşı\'nın ardından 1187\'de Kudüs\'ü Haçlılardan geri almıştır; bu '
        'olay Orta Doğu tarihinde derin iz bırakmıştır.',
  ),
  'offline_2090': ExplanationOverride(
    ku:
        'Selahedînê Eyûbî li ser xerabeyên Fatimiyan Dewleta Eyûbiyan ava '
        'kir û bû yekem sultanê wê.',
    tr:
        'Selahaddin Eyyubi, Fatımi Devleti\'nin yıkıntıları üzerine Eyyubi '
        'Devleti\'ni kurmuş ve onun ilk sultanı olmuştur.',
  ),
  'offline_2091': ExplanationOverride(
    ku:
        'Dewleta Eyûbiyan di sedsala 12an û 13an de li Misrê, Şamê û beşên '
        'din ên Rojhilata Navîn desthilat bû, heta ku Memlûkan cih girtin.',
    tr:
        'Eyyubi Devleti, 12. ve 13. yüzyıllarda Mısır, Şam ve Orta Doğu\'nun '
        'diğer bölgelerinde hüküm sürmüş, yerini Memlüklere bırakmıştır.',
  ),
  'offline_2092': ExplanationOverride(
    ku:
        'Mîrgeha Erdelanê yek ji çar mîrgehên mezin ên kurdî bû (digel Botan, '
        'Baban û Soran) û navenda wê Sine (Senendec, îro li Îranê) bû.',
    tr:
        'Erdelan Beyliği, Botan, Baban ve Soran ile birlikte dört büyük Kürt '
        'beyliğinden biriydi; merkezi bugün İran\'da bulunan Sine (Senendec) '
        'idi.',
  ),
  'offline_2093': ExplanationOverride(
    ku:
        'Kelheya Hewlêrê li ser girekî ye ku bi hezaran salan e bêyî '
        'navber tê nişteciyî; ji ber vê taybetiyê wek yek ji bajarên herî '
        'kevn ên cîhanê tê zanîn.',
    tr:
        'Erbil Kalesi, binlerce yıldır kesintisiz olarak yerleşim gören bir '
        'höyük üzerine kuruludur; bu özelliğiyle dünyanın en eski '
        'şehirlerinden biri olarak bilinir.',
  ),
  'offline_2094': ExplanationOverride(
    ku:
        'Kelheya Hewlêrê di sala 2014an de ket lîsteya Mîrateya Cîhanê ya '
        'UNESCOyê.',
    tr: 'Erbil Kalesi, 2014 yılında UNESCO Dünya Mirası listesine girmiştir.',
  ),
  'offline_2095': ExplanationOverride(
    ku:
        'Komara Mehabadê di 22ê Rêbendana 1946an de li Îranê hat ragihandin '
        'û tenê çend meh domand; wek yekem tecrûbeya dewleta kurdî ya nûjen '
        'tê binavkirin.',
    tr:
        'Mahabad Cumhuriyeti, 22 Ocak 1946\'da İran\'da ilan edilmiş ve '
        'yalnızca birkaç ay ayakta kalabilmiştir; modern anlamda ilk Kürt '
        'devlet deneyimi olarak anılır.',
  ),
  'offline_2096': ExplanationOverride(
    ku:
        'Qazî Mihemed serokê Komara Mehabadê bû; piştî hilweşîna komarê di '
        '1947an de hat darvekirin.',
    tr:
        'Qazî Mihemed, Mahabad Cumhuriyeti\'nin cumhurbaşkanıydı; cumhuriyetin '
        'çöküşünden sonra 1947\'de idam edilmiştir.',
  ),
  'offline_2097': ExplanationOverride(
    ku:
        'Mêrdîn bi avahiyên xwe yên ji kevirê zer ê tiraşandî, ku li ser '
        'girekî li dora Deşta Mezopotamyayê hatine ristin, navdar e.',
    tr:
        'Mardin, Mezopotamya ovasına bakan bir tepeye sıralanmış, sarı kesme '
        'taştan yapılar mimarisiyle ünlüdür.',
  ),
  'offline_2098': ExplanationOverride(
    ku:
        'Heskîfa kevnar li kêleka Çemê Dîcle bû; beşeke mezin a bajêr piştî '
        'çêbûna Bendava Ilîsûyê di bin avê de maye.',
    tr:
        'Tarihi Hasankeyf, Dicle Nehri kıyısında yer alıyordu; kentin büyük '
        'bölümü Ilısu Barajı\'nın oluşturduğu göl altında kalmıştır.',
  ),
  'offline_2099': ExplanationOverride(
    ku:
        'Mezopotamya, li navbera Dîcle û Ferat de, yek ji cihên pêşî yê '
        'çandiniyê û bajarîbûnê ye û bi navê "Landa Du Çeman" tê zanîn.',
    tr:
        'Mezopotamya, Dicle ile Fırat nehirleri arasında yer alır; '
        'tarımın ve şehirleşmenin ilk merkezlerinden biridir.',
  ),
  'offline_2100': ExplanationOverride(
    ku:
        'Navê "Mezopotamya" ji yewnaniya kevn tê, "mesos" (navber) û '
        '"potamos" (çem) lê hatiye zêdekirin.',
    tr:
        '"Mezopotamya" adı Eski Yunancadan gelir; "mesos" (ara) ve "potamos" '
        '(nehir) sözcüklerinden türetilmiştir.',
  ),
  'offline_2101': ExplanationOverride(
    ku:
        'Mîrgeha Soran yek ji çar mîrgehên mezin ên kurdî bû; navenda wê '
        'Rewandiz bû, li herêmeke çiyayî ya dijwar a Kurdistana Iraqê.',
    tr:
        'Soran Beyliği, dört büyük Kürt beyliğinden biriydi; merkezi, Irak '
        'Kürdistanı\'nın dağlık ve ulaşımı zor bir bölgesinde bulunan '
        'Rewandiz\'di (Rawanduz).',
  ),
  'offline_2102': ExplanationOverride(
    ku:
        'Padîşahiya Urartû (sedsala 9-6an B.Z.) li dora Gola Wanê hate '
        'avakirin û paytexta wê Tuşpa bû, li cihê Wanê ya îro.',
    tr:
        'Urartu Krallığı (MÖ 9-6. yüzyıllar) Van Gölü çevresinde kurulmuştur; '
        'başkenti günümüz Van kentinin bulunduğu Tuşpa\'ydı.',
  ),
  'offline_2103': ExplanationOverride(
    ku:
        '"Amed" navê kurdî yê Diyarbekirê ye; herdu nav jî li herêmê bi '
        'awayekî berfireh tên bikaranîn.',
    tr:
        '"Amed", Diyarbakır\'ın Kürtçe adıdır; her iki isim de bölgede '
        'yaygın biçimde kullanılır.',
  ),
  'offline_2104': ExplanationOverride(
    ku:
        'Avakirina Qesra Îshaq Paşa nêzîkî sed salan domand û di sala 1784an '
        'de ji aliyê malbata mîrên Bazîdê ve hate temamkirin.',
    tr:
        'İshak Paşa Sarayı\'nın inşası yaklaşık yüz yıl sürmüş ve 1784\'te '
        'Doğubayazıt beyleri ailesi tarafından tamamlanmıştır.',
  ),
  'offline_2105': ExplanationOverride(
    ku:
        'Împaratoriya Medan li Zagrosê (rojavayê Îranê) derket holê û bi '
        'hevkariya Babîliyan Împaratoriya Asûrî hilweşand (612 B.Z.).',
    tr:
        'Med İmparatorluğu, Zagros bölgesinde (İran\'ın batısı) ortaya çıkmış '
        've Babilliler ile birlikte Asur İmparatorluğu\'nu yıkmıştır (MÖ 612).',
  ),
  'offline_2106': ExplanationOverride(
    ku:
        'Mîrgeha Baban çaremîn mîrgeha mezin a kurdî bû; mîrê wê Îbrahîm '
        'Paşa Silêmanî wek navenda xwe ava kir.',
    tr:
        'Baban Beyliği, dördüncü büyük Kürt beyliğiydi; beyi İbrahim Paşa, '
        'Süleymaniye\'yi kendi merkezleri olarak inşa etmiştir.',
  ),
  'offline_2107': ExplanationOverride(
    ku:
        'Silêmanî di 1784an de ji aliyê Îbrahîm Paşayê Babanî ve wek '
        'navenda mîrgehê hate avakirin.',
    tr:
        'Süleymaniye, 1784\'te Baban Beyi İbrahim Paşa tarafından beyliğin '
        'merkezi olarak kurulmuştur.',
  ),
  'offline_2108': ExplanationOverride(
    ku:
        'Birca Keçî bircê herî navdar ê sûrên Amedê ye; navê wê ji '
        'peykerên bizinan ên li ser dîwêr tê.',
    tr:
        'Keçi Burcu (Birca Keçî), Diyarbakır Surları\'nın en bilinen '
        'burcudur; adını duvar üzerindeki keçi kabartmalarından alır.',
  ),
  'offline_2109': ExplanationOverride(
    ku:
        'Padîşahên Urartû nivîsên xwe bi tîpên mixî yên bi zimanê Urartî li '
        'kevir hiştine; piraniya wan li dora Gola Wanê hatine dîtin.',
    tr:
        'Urartu kralları, Urartuca çivi yazısıyla kayalara yazıtlar '
        'bıraktı; bunların çoğu Van Gölü çevresinde bulunmuştur.',
  ),
  'offline_2110': ExplanationOverride(
    ku:
        'Xirabreşk (Göbekli Tepe), nêzîkî Rihayê, yek ji kevintirîn '
        'perestgehên mirovahiyê ye (nêzîkî 9.600 B.Z.) û di 2018an de ket '
        'lîsteya UNESCOyê.',
    tr:
        'Göbekli Tepe, Urfa (Riha) yakınlarında yer alan ve insanlığın '
        'bilinen en eski tapınak yapılarından biridir (MÖ yaklaşık 9.600); '
        '2018\'de UNESCO listesine girmiştir.',
  ),
  // ---- Edebiyat ----
  'offline_0649': ExplanationOverride(
    ku:
        'Di edebiyata kurdî de "çîrok" çîroka kurt a pexşan e. Bûyer, karakter '
        'û peyamekê di forma kurt de digihîne; kevneşopiya devkî ya kurdî '
        'dewlemend e bi çîrokên gelêrî.',
    tr:
        'Kürt edebiyatında "çîrok" kısa öykü/hikâye demektir. Olay, karakter ve '
        'bir mesajı kısa biçimde aktarır; Kürt sözlü geleneği halk '
        'hikâyeleriyle zengindir.',
  ),
  'offline_0654': ExplanationOverride(
    ku:
        'Di edebiyata kurdî de "helbest" tê wateya şiîrê. Bi pîvan, kafiye û '
        'hestan ve girêdayî ye; helbestvanên klasîk wek Melayê Cizîrî û Ehmedê '
        'Xanî ev huner bilind kirine.',
    tr:
        'Kürt edebiyatında "helbest" şiir anlamına gelir. Ölçü, kafiye ve '
        'duyguyla ilişkilidir; Melayê Cizîrî ve Ehmedê Xanî gibi klasik şairler '
        'bu sanatı yükseltmiştir.',
  ),
  'offline_0660': ExplanationOverride(
    ku:
        'Di edebiyata kurdî de "destan" çîroka dirêj a qehremanî ye. Bûyerên '
        'mezin, şer û lehengan vedibêje; "Memê Alan" yek ji destanên navdar ên '
        'kurdî ye.',
    tr:
        'Kürt edebiyatında "destan", kahramanlık anlatan uzun bir anlatıdır. '
        'Büyük olayları, savaşları ve kahramanları anlatır; "Memê Alan" ünlü '
        'Kürt destanlarından biridir.',
  ),
  'offline_0669': ExplanationOverride(
    ku:
        'Di edebiyatê de "mecaz" wateya rast a peyvê nayê, wateyeke veguhêz '
        'bikar tîne. Wek gotina "şêr" ji bo mirovê wêrek; ji bo hêz û bandorê '
        'tê xebitandin.',
    tr:
        'Edebiyatta "mecaz", bir sözcüğün gerçek anlamını değil aktarılmış '
        'anlamını kullanmaktır. "Aslan" sözünü yiğit biri için kullanmak gibi; '
        'anlatıma güç ve etki katar.',
  ),
  'offline_0672': ExplanationOverride(
    ku:
        'Di helbestê de "kafiye" lihevhatina dengan e li dawiya rêzan. Awaz û '
        'ahenga şiîrê xurt dike û di bîra mirovan de hêsantir dimîne.',
    tr:
        'Şiirde "kafiye", dize sonlarındaki ses uyumudur. Şiirin ahengini '
        'güçlendirir ve akılda kalmasını kolaylaştırır.',
  ),
  // ---- Edebiyat (klasîk û nûjen) ----
  'offline_2111': ExplanationOverride(
    ku:
        'Ehmedê Xanî bi Kurmancî nivîsî da ku zimanê kurdî di edebiyata '
        'klasîk de cihekî hêja bigire; Mem û Zîn hê jî wek serpêhatiya '
        'edebiyata kurdî tê dîtin.',
    tr:
        'Ehmedê Xanî, Kürtçenin klasik edebiyatta saygın bir yer edinmesi '
        'için Kurmanci yazmıştır; Mem û Zîn hâlâ Kürt edebiyatının başyapıtı '
        'sayılır.',
  ),
  'offline_2112': ExplanationOverride(
    ku:
        'Mem û Zîn mesnewiyeke dirêj a bi helbest e ku Ehmedê Xanî di 1695an '
        'de li Bazîdê nivîsiye.',
    tr:
        'Mem û Zîn, Ehmedê Xanî\'nin 1695\'te Doğubayazıt\'ta (Bazîd) '
        'kaleme aldığı uzun bir mesnevidir.',
  ),
  'offline_2113': ExplanationOverride(
    ku:
        'Xanî berhema xwe di sala 1695an de, li bin çavdêriya mîrên Bazîdê, '
        'qedand.',
    tr:
        'Xanî, eserini Bazîd (Doğubayazıt) beylerinin himayesinde 1695\'te '
        'tamamlamıştır.',
  ),
  'offline_2114': ExplanationOverride(
    ku:
        'Di çîroka Mem û Zînê de evîna du dilan bi dilşikestin diqede; Xanî '
        'di pêşgotina xwe de vê evînê wek sembola perçebûn û bêyekîtiya '
        'kurdan jî dinirxîne.',
    tr:
        'Mem ile Zîn\'in aşkı hikâyede trajik biçimde sona erer; Xanî '
        'önsözünde bu aşkı, Kürtlerin bölünmüşlüğünün bir simgesi olarak da '
        'yorumlar.',
  ),
  'offline_2115': ExplanationOverride(
    ku:
        'Memê Alan destaneke gelêrî ya devkî ye ku berî Xanî jî di nav gel '
        'de dihat gotin; Xanî ev materyal wergirt û wê bi awayekî edebî yê '
        'bilind nivîsî.',
    tr:
        'Memê Alan, Xanî\'den önce de halk arasında sözlü olarak anlatılan '
        'bir destandır; Xanî bu malzemeyi alıp yüksek edebî bir biçimde '
        'yeniden yazmıştır.',
  ),
  'offline_2116': ExplanationOverride(
    ku:
        'Melayê Cizîrî di sedsala 16-17an de li Cizîrê jiyaye û Dîwana xwe '
        'ya bi helbestên tesewifî wek yek ji lûtkeyên helbesta klasîk a '
        'Kurmancî tê hesibandin.',
    tr:
        '16-17. yüzyılda Cizre\'de yaşamış olan Melayê Cizîrî\'nin tasavvufî '
        'şiirlerden oluşan Dîwan\'ı, klasik Kurmanci şiirinin doruklarından '
        'biri sayılır.',
  ),
  'offline_2117': ExplanationOverride(
    ku:
        'Feqiyê Teyran (sedsala 17an) di helbestên xwe de pir caran bi '
        'teyran re diaxive; ev şêwaz têkiliya wî ya nêzîk bi xwezayê re '
        'nîşan dide.',
    tr:
        '17. yüzyıl şairi Feqiyê Teyran, şiirlerinde sıkça kuşlarla konuşur; '
        'bu üslup, doğayla kurduğu yakın bağı yansıtır.',
  ),
  'offline_2118': ExplanationOverride(
    ku:
        'Navê wî yê şi\'rî "Feqiyê Teyran" tê wateya "feqîhê teyran" (yê ku '
        'zimanê teyran dizane); efsaneyek dibêje wî ji zaroktiyê ve bi '
        'teyran re dipeyivî.',
    tr:
        'Mahlası "kuşların fakihi" (kuşların dilini bilen) anlamına gelir; '
        'bir efsaneye göre çocukluğundan beri kuşlarla konuşabildiği '
        'söylenir.',
  ),
  'offline_2119': ExplanationOverride(
    ku:
        'Celadet Alî Bedirxan, birayê xwe Kamiran re, kovara Hawar derxist '
        'da ku ziman û çanda kurdî bi nivîskî bijî û pêş bikeve.',
    tr:
        'Celadet Alî Bedirxan, kardeşi Kamiran ile birlikte, Kürt dilinin ve '
        'kültürünün yazıyla yaşaması ve gelişmesi için Hawar dergisini '
        'çıkarmıştır.',
  ),
  'offline_2120': ExplanationOverride(
    ku:
        'Hawar di 1932an de li Şamê dest bi weşanê kir û di dîroka '
        'zimanê kurdî de gaveke girîng bû, ji ber ku alfabeya Latînî ya '
        'Kurmancî jê belav bû.',
    tr:
        'Hawar, 1932\'de Şam\'da yayın hayatına başlamış ve Kurmanci Latin '
        'alfabesini yaygınlaştırdığı için Kürt dili tarihinde önemli bir adım '
        'olmuştur.',
  ),
  'offline_2121': ExplanationOverride(
    ku:
        'Malbata Bedirxan piştî hilweşîna Osmaniyan sirgûnî Sûriyê bûbû; ji '
        'ber vê yekê Hawar li Şamê, ne li welatê kurdan, dihat weşandin.',
    tr:
        'Bedirxan ailesi Osmanlı\'nın çöküşünün ardından Suriye\'ye '
        'sürgün edilmişti; bu yüzden Hawar, Kürt topraklarında değil '
        'Şam\'da yayımlanıyordu.',
  ),
  'offline_2122': ExplanationOverride(
    ku:
        'Celadet Alî Bedirxan di 1932an de li ser bingeha tîpên Latînî '
        'alfabeyeke ji bo Kurmancî amade kir; ev alfabe hê jî li Tirkiye, '
        'Sûriye û derveyî welêt tê bikaranîn.',
    tr:
        'Celadet Alî Bedirxan, 1932\'de Latin harflerine dayalı bir Kurmanci '
        'alfabesi hazırlamıştır; bu alfabe bugün de Türkiye, Suriye ve '
        'diaspora ortamlarında kullanılmaktadır.',
  ),
  'offline_2123': ExplanationOverride(
    ku:
        'Cegerxwîn (1903-1984) bi hezaran helbestên xwe yên li ser evîn, '
        'welatparêzî û têkoşîna civakî bi kurdî nivîsiye; wek yek ji '
        'helbestvanên herî hêja yên sedsala 20an tê zanîn.',
    tr:
        'Cegerxwîn (1903-1984), aşk, vatanseverlik ve toplumsal mücadele '
        'üzerine yazdığı binlerce şiirle 20. yüzyılın en önemli Kürt '
        'şairlerinden biri sayılır.',
  ),
  'offline_2124': ExplanationOverride(
    ku:
        'Navê rastîn ê Cegerxwîn Şêxmûs Hesen e; "Cegerxwîn" (ciger + '
        'xwîn, "kanayan ciğer") wek navê helbestî hatiye hilbijartin.',
    tr:
        'Cegerxwîn\'in asıl adı Şêxmûs Hesen\'dir; "Cegerxwîn" (kanayan '
        'ciğer) sonradan benimsenen bir şair mahlasıdır.',
  ),
  'offline_2125': ExplanationOverride(
    ku:
        'Mehmed Uzun (1953-2007) di sirgûnê de li Swêdê bi Kurmancî roman '
        'nivîsî û wek damezrînerê romana kurdî ya nûjen tê hesibandin.',
    tr:
        'Mehmed Uzun (1953-2007), İsveç\'teki sürgün yıllarında Kurmanci '
        'roman yazmış ve modern Kürt romanının kurucularından biri olarak '
        'kabul edilir.',
  ),
  'offline_2126': ExplanationOverride(
    ku:
        '"Siya Evînê" (Evînê Siya) yek ji romanên navdar ên Mehmed Uzun e; '
        'bi Kurmancî hatiye nivîsîn û paşê ji gelek zimanan ve hatiye '
        'wergerandin.',
    tr:
        '"Siya Evînê" (Aşkın Gölgesi), Mehmed Uzun\'un tanınmış romanlarından '
        'biridir; Kurmanci yazılmış ve sonradan birçok dile çevrilmiştir.',
  ),
  'offline_2127': ExplanationOverride(
    ku:
        'Uzun, di dema ku Kurmancî li Tirkiyeyê qedexe bû de, bi hişmendî '
        'romanên xwe bi vî zimanî nivîsî da ku edebiyata kurdî ya nûjen ava '
        'bike.',
    tr:
        'Uzun, Kurmancinin Türkiye\'de yasaklı olduğu dönemde, bilinçli '
        'olarak romanlarını bu dilde yazarak modern Kürt edebiyatını inşa '
        'etmeye çalışmıştır.',
  ),
  'offline_2128': ExplanationOverride(
    ku:
        'Elî Herîrî bi gelemperî wek yek ji pêşengên herî pêşî yên helbesta '
        'klasîk a Kurmancî (dor. sedsala 11an) tê binavkirin, her çend '
        'agahiyên li ser jiyana wî têrker nebin jî.',
    tr:
        'Elî Herîrî, yaşamına dair kesin bilgiler sınırlı olsa da genellikle '
        'klasik Kurmanci şiirinin en erken temsilcilerinden biri (yaklaşık '
        '11. yüzyıl) olarak anılır.',
  ),
  'offline_2129': ExplanationOverride(
    ku:
        'Destan celebeke edebiyata devkî ya dirêj e ku serpêhatiyên '
        'lehengan, şer û evînan bi awayekî pîvankirî vedibêje; li Kurdistanê '
        '"Memê Alan" û "Kela Dimdim" mînakên navdar in.',
    tr:
        'Destan, kahramanların, savaşların ve aşkların ölçülü biçimde '
        'anlatıldığı uzun bir sözlü edebiyat türüdür; Kürtler arasında '
        '"Memê Alan" ve "Kela Dimdim" bilinen örneklerdir.',
  ),
  // ---- Muzîk ----
  'offline_0881': ExplanationOverride(
    ku:
        'Di muzîka kurdî de "stran" tê wateya kilam/stranê. Dikare evînî, '
        'qehremanî an gelêrî be; dengbêj û hunermend wan ji nifşê re davêjin.',
    tr:
        'Kürt müziğinde "stran" şarkı/türkü demektir. Aşk, kahramanlık ya da '
        'halk temalı olabilir; dengbêjler ve sanatçılar bunları kuşaklara '
        'aktarır.',
  ),
  'offline_0885': ExplanationOverride(
    ku:
        'Di muzîka kurdî de "def" sazeke lêdanê ye (def/bendîr). Di govend û '
        'şahiyan de ritmê dide û pirî caran bi erbaneyê re tê xebitandin.',
    tr:
        'Kürt müziğinde "def" vurmalı bir çalgıdır (bendir/tef). Halaylarda ve '
        'şenliklerde ritmi verir, çoğu zaman erbane ile birlikte kullanılır.',
  ),
  'offline_0889': ExplanationOverride(
    ku:
        'Di muzîka kurdî de "erbane" sazeke lêdanê ya dor e (def a mezin). Di '
        'dawet û dîlanan de ritma bingehîn peyda dike.',
    tr:
        'Kürt müziğinde "erbane", yuvarlak vurmalı bir çalgıdır (büyük tef). '
        'Düğün ve halaylarda temel ritmi sağlar.',
  ),
  'offline_0892': ExplanationOverride(
    ku:
        'Di muzîka kurdî de "tembûr" sazeke bi têl e. Bi taybetî di muzîka olî '
        'û aşiqî de tê bikaranîn û dengê wê yê kûr navdar e.',
    tr:
        'Kürt müziğinde "tembûr" telli bir çalgıdır. Özellikle dinî ve âşık '
        'müziğinde kullanılır ve derin tınısıyla bilinir.',
  ),
  // ---- Siyaset / Paradigma (nötr, terim/tanım odaklı) ----
  'offline_2290': ExplanationOverride(
    ku:
        '"Jin, Jiyan, Azadî" dirûşmeke navdar e; tê de "jin" tê wateya "kadın". '
        'Peyv bi "jiyan" (hayat) û "azadî" (özgürlük) re tê bikaranîn.',
    tr:
        '"Jin, Jiyan, Azadî" bilinen bir slogandır; buradaki "jin" Kürtçede '
        '"kadın" demektir. Söz "jiyan" (hayat) ve "azadî" (özgürlük) '
        'sözcükleriyle birlikte kullanılır.',
  ),
  'offline_2291': ExplanationOverride(
    ku:
        'Peyva "azadî" di Kurmancî de tê wateya "özgürlük". Di gelek dirûşm û '
        'stranan de wek nirxeke bingehîn derbas dibe.',
    tr:
        '"Azadî" sözcüğü Kürtçede "özgürlük" anlamına gelir. Birçok slogan ve '
        'şarkıda temel bir değer olarak geçer.',
  ),
  'offline_2292': ExplanationOverride(
    ku:
        '"Jineolojî" wek "zanista jinê" tê pênasekirin; li dora zanîna jinê û '
        'rexneya baviksalariyê (patriyarka) ava dibe.',
    tr:
        '"Jineolojî" en kısa biçimde "kadın bilimi" olarak açıklanır; kadın '
        'bilgisi ve patriarka eleştirisi etrafında kurulan bir kavramdır.',
  ),
  'offline_2298': ExplanationOverride(
    ku:
        'Peyva "hevaltî" tê wateya "yoldaşlık/arkadaşlık". Çanda hevaltiyê li '
        'ser hevgirtin û piştevaniya hevdû ava dibe.',
    tr:
        '"Hevaltî" sözcüğü "yoldaşlık/arkadaşlık" anlamına gelir. Hevaltî '
        'kültürü dayanışma ve karşılıklı destek üzerine kuruludur.',
  ),
  'offline_2326': ExplanationOverride(
    ku:
        'Têgîna "konfederalîzma demokratîk" ji aliyê Abdullah Ocalan ve hatiye '
        'pêşxistin. Ev têgîn li ser demokrasiya herêmî, parastina jinê û '
        'ekolojiyê disekine.',
    tr:
        '"Demokratik konfederalizm" kavramı Abdullah Öcalan tarafından '
        'geliştirilmiştir. Yerel demokrasi, kadın özgürlüğü ve ekoloji '
        'vurgusuyla tanımlanan bir kavramdır.',
  ),
  'offline_2327': ExplanationOverride(
    ku:
        'Wek alternatîfa "modernîteya kapîtalîst", têgîna "modernîteya '
        'demokratîk" tê pêşniyarkirin. Ew rexneya navend-dewlet û pergala '
        'kapîtalîst dike.',
    tr:
        '"Kapitalist modernite"ye alternatif olarak önerilen kavram '
        '"demokratik modernite"dir. Merkezî ulus-devlet ve kapitalist sisteme '
        'yönelik bir eleştiri içerir.',
  ),
  'offline_2282': ExplanationOverride(
    ku:
        'Pergala "hevserokatî" nûnertiya wekhev a jin û mêr û birêvebirina '
        'hevpar kurumsal dike. Armanc wekheviya zayendî ye di rêvebirinê de.',
    tr:
        '"Eşbaşkanlık" sistemi kadın-erkek eşit temsili ve ortak yönetimi '
        'kurumsallaştırmayı hedefler. Amaç, yönetimde cinsiyet eşitliğidir.',
  ),
  'offline_2334': ExplanationOverride(
    ku:
        'Daxwaza "xweseriya demokratîk" tê wateya ku civak karûbarên xwe yên '
        'herêmî bi xwe birêve bibin. Li ser xwe-birêvebirina herêmî disekine.',
    tr:
        '"Demokratik özerklik" talebi, toplulukların yerel işlerini '
        'kendilerinin yönetmesini ifade eder. Yerel öz-yönetim vurgusu taşır.',
  ),
  'offline_2335': ExplanationOverride(
    ku:
        'Daxwaza "perwerdeya bi zimanê dayikê" dikeve kategoriya mafên çandî û '
        'zimanî. Parastina zimanê kêmaniyan armanc dike.',
    tr:
        '"Anadilde eğitim" talebi, kültürel ve dilsel haklar kategorisine '
        'girer. Azınlık dillerinin korunmasını hedefler.',
  ),
};
