/// 2026-10-27: sekiz yeni günlük hikâye (doktorda, otobüs, düğün, Newroz,
/// misafir, lokanta, telefon, okul). Taslak Gemini; dil jürisi Codex +
/// Grok + Gemini (her değişiklik en az iki modelin onayıyla). Mini rehberleri
/// yoktur (rehber isteğe bağlı).
library;

import 'story.dart';

final Story bijiskStory = Story(
  id: 'bijisk',
  titleKu: 'Li cem bijîşkî',
  titleTr: 'Doktorda',
  startNodeId: 'start',
  nodes: [
    const StoryNode(
      id: 'start',
      textKu:
          'Tu nexweş î, serê te diêşe. Tu diçî nexweşxaneyê. Bijîşk Azad li benda te ye. Ew dibêje: \'Rojbaş! Çi nexweşiya te heye?\'',
      textTr:
          'Hastasın, başın ağrıyor. Hastaneye gidiyorsun. Doktor Azad seni bekliyor. O: \'Günaydın! Neyin var?\' diyor.',
      choices: [
        StoryChoice(
          labelKu: 'Rojbaş doktor, serê min pir diêşe.',
          labelTr: 'Günaydın doktor, başım çok ağrıyor.',
          nextNodeId: 'muayene',
          feedbackKu: 'Ev bersiveke pir zelal û rêzdar e.',
          feedbackTr: 'Bu çok açık ve saygılı bir yanıttır.',
        ),
        StoryChoice(
          labelKu: 'Ez naxwazim biaxivim, tenê derman bide min.',
          labelTr: 'Konuşmak istemiyorum, sadece bana ilaç ver.',
          nextNodeId: 'derman_pirsin',
          feedbackKu: 'Bijîşk pêşî dixwaze nîşaneyên te fêm bike.',
          feedbackTr: 'Doktor öncelikle belirtilerini anlamak ister.',
        ),
      ],
    ),
    const StoryNode(
      id: 'derman_pirsin',
      textKu:
          'Bijîşk Azad bi nermî dibêje: \'Ji bo dermanê rast, divê ez sedema êşê bizanim. Gewriya te an zikê te jî diêşe?\'',
      textTr:
          'Doktor Azad nazikçe şöyle der: \'Doğru ilaç için ağrının nedenini bilmeliyim. Boğazın veya karnın da ağrıyor mu?\'',
      choices: [
        StoryChoice(
          labelKu: 'Biborin, gewriya min jî diêşe û taya min heye.',
          labelTr: 'Kusura bakmayın, boğazım da ağrıyor ve ateşim var.',
          nextNodeId: 'muayene',
          feedbackKu: 'Tu ji bijîşkî re qala êşa xwe dikî.',
          feedbackTr: 'Doktora ağrından söz ediyorsun.',
        ),
      ],
    ),
    const StoryNode(
      id: 'muayene',
      textKu:
          'Bijîşk Azad li gewriya te dinêre û germahiya te dipîve. Ew dibêje: \'Te serma girtiye. Tu dixwazî dermanê xwe çawa bistînî?\'',
      textTr:
          'Doktor Azad boğazına bakıyor ve ateşini ölçüyor. Şöyle diyor: \'Üşütmüşsün. İlacını nasıl almak istersin?\'',
      choices: [
        StoryChoice(
          labelKu: 'Ez dixwazim heban bixwim.',
          labelTr: 'Hap içmek istiyorum.',
          nextNodeId: 'end_hab',
          feedbackKu: 'Vexwarina dermanan bi rêkûpêk zû te baş dike.',
          feedbackTr: 'İlaçları düzenli içmek seni çabuk iyileştirir.',
        ),
        StoryChoice(
          labelKu: 'Ez ji heban hez nakim, heke şerbeta dermanî hebe çêtir e.',
          labelTr: 'Hap sevmiyorum, şurup varsa daha iyidir.',
          nextNodeId: 'end_siroop',
          feedbackKu:
              'Parvekirina tercîha xwe rasterast bi bijîşkî re bi feyde ye.',
          feedbackTr: 'Tercihini doğrudan doktorla paylaşmak faydalıdır.',
        ),
      ],
    ),
    const StoryNode(
      id: 'end_hab',
      textKu:
          'Bijîşk Azad reçeteyek dinivîse: \'Rojê du caran van heban bixwe û ava nîvgerm vexwe.\' Tu spasiya wî dikî û diçî dermanxaneyê. Şîfa be!',
      textTr:
          'Doktor Azad bir reçete yazıyor: \'Günde iki kez bu hapları iç ve ılık su tüket.\' Ona teşekkür edip eczaneye gidiyorsun. Geçmiş olsun!',
    ),
    const StoryNode(
      id: 'end_siroop',
      textKu:
          'Bijîşk Azad şerbeteke dermanî dinivîse: \'Rojê sê caran vê şerbeta şîrîn vexwe û bêhna xwe vede.\' Tu spasiya wî dikî û diçî malê. Şîfa be!',
      textTr:
          'Doktor Azad bir şurup yazıyor: \'Günde üç kez bu tatlı şurubu iç ve dinlen.\' Ona teşekkür edip eve gidiyorsun. Geçmiş olsun!',
    ),
  ],
);

final Story otobusStory = Story(
  id: 'otobus',
  titleKu: 'Rêwîtiya otobûsê',
  titleTr: 'Otobüs yolculuğu',
  startNodeId: 'start',
  nodes: [
    const StoryNode(
      id: 'start',
      textKu:
          'Tu li otogarê yî. Tu dixwazî herî Amedê. Li pêşiya te karmend Zelal rûniştiye.',
      textTr:
          'Otogardasın. Diyarbakır\'a gitmek istiyorsun. Önünde görevli Zelal oturuyor.',
      choices: [
        StoryChoice(
          labelKu: 'Rojbaş xanim, ji bo Amedê bilêt heye?',
          labelTr: 'Günaydın hanımefendi, Diyarbakır için bilet var mı?',
          nextNodeId: 'bilet_xwestin',
          feedbackKu: 'Ji bo destpêka axaftinê silaveke xweş e.',
          feedbackTr: 'Konuşmaya başlamak için güzel bir selam.',
        ),
        StoryChoice(
          labelKu: 'Otobûsa Amedê kengî radibe?',
          labelTr: 'Diyarbakır otobüsü ne zaman kalkıyor?',
          nextNodeId: 'saet_pirsin',
          feedbackKu: 'Pirsiyariyeke rasterast û pratîk e.',
          feedbackTr: 'Doğrudan ve pratik bir soru.',
        ),
      ],
    ),
    const StoryNode(
      id: 'saet_pirsin',
      textKu:
          'Zelal bi ken dibêje: \'Otobûs di saet dehan de radibe. Tu bilêt dixwazî?\'',
      textTr:
          'Zelal gülümseyerek: \'Otobüs saat onda kalkıyor. Bilet ister misin?\' diyor.',
      choices: [
        StoryChoice(
          labelKu: 'Erê, ji kerema xwe re bilêtek bidin min.',
          labelTr: 'Evet, lütfen bana bir bilet verin.',
          nextNodeId: 'bilet_xwestin',
          feedbackKu: 'Tu bi nermî bilêtekê dixwazî.',
          feedbackTr: 'Nazikçe bir bilet istiyorsun.',
        ),
      ],
    ),
    const StoryNode(
      id: 'bilet_xwestin',
      textKu:
          'Zelal dibêje: \'Du kursî vala ne: yek li ber pencereyê ye, yek li ber korîdorê ye. Tu kîjanê hildibijêrî?\'',
      textTr:
          'Zelal: \'İki koltuk boş: biri cam kenarında, biri koridor tarafında. Hangisini seçersin?\' diyor.',
      choices: [
        StoryChoice(
          labelKu: 'Ez kursiya ber pencereyê dixwazim.',
          labelTr: 'Cam kenarındaki koltuğu istiyorum.',
          nextNodeId: 'otobus_siwarbun',
          feedbackKu: 'Temaşekirina rê rêwîtiyê xweştir dike.',
          feedbackTr: 'Yolu izlemek yolculuğu güzelleştirir.',
        ),
        StoryChoice(
          labelKu: 'Kursiya ber korîdorê ji min re çêtir e.',
          labelTr: 'Koridor tarafındaki koltuk benim için daha iyi.',
          nextNodeId: 'otobus_siwarbun',
          feedbackKu: 'Ji bo rabûn û rûniştinê ciyekî rehet e.',
          feedbackTr: 'Kalkıp oturmak için rahat bir yerdir.',
        ),
      ],
    ),
    const StoryNode(
      id: 'otobus_siwarbun',
      textKu:
          'Tu bilêta xwe digirî û li otobûsê siwar dibî. Şêrko li kêleka te rûniştiye û silavê dide: \'Rêwîtiya te bi xêr be!\'',
      textTr:
          'Biletini alıp otobüse biniyorsun. Şêrko yanına oturmuş ve selam veriyor: \'İyi yolculuklar!\'',
      choices: [
        StoryChoice(
          labelKu: 'Gelek spas, rêwîtiya te jî bi xêr be!',
          labelTr: 'Çok teşekkürler, senin de yolculuğun iyi geçsin!',
          nextNodeId: 'end_sohbet',
          feedbackKu: 'Bersiveke germ û civakî ye.',
          feedbackTr: 'Sıcak ve sosyal bir yanıttır.',
        ),
        StoryChoice(
          labelKu: 'Spas, ez ê guhdariya muzîkê bikim.',
          labelTr: 'Teşekkürler, ben müzik dinleyeceğim.',
          nextNodeId: 'end_muzik',
          feedbackKu: 'Rêwîtiyeke bêdeng jî carinan pêwîst e.',
          feedbackTr: 'Bazen sessiz bir yolculuk da gereklidir.',
        ),
      ],
    ),
    const StoryNode(
      id: 'end_sohbet',
      textKu:
          'Hûn heta dawiya rê bi hevaltiyeke xweş sohbet dikin. Rê zû diqede û tu bi silametî digihîjî Amedê.',
      textTr:
          'Yolun sonuna kadar güzel bir dostlukla sohbet ediyorsunuz. Yol çabuk bitiyor ve esenlikle Diyarbakır\'a varıyorsun.',
    ),
    const StoryNode(
      id: 'end_muzik',
      textKu:
          'Tu berguhkên xwe datînî ser guhên xwe û bi aramî li stranên kurdî guhdarî dikî. Tu digihîjî Amedê.',
      textTr:
          'Kulaklıklarını takıp huzurla Kürtçe şarkılar dinliyorsun. Diyarbakır\'a varıyorsun.',
    ),
  ],
);

final Story dawetStory = Story(
  id: 'dawet',
  titleKu: 'Li dawetê',
  titleTr: 'Düğünde',
  startNodeId: 'start',
  nodes: [
    const StoryNode(
      id: 'start',
      textKu:
          'Tu li daweta kuzenê xwe yî. Li hewşê dengê daholê û zurnayê bilind dibe. Dilan tê cem te û dibêje: \'Tu çima bi tenê rûniştî yî?\'',
      textTr:
          'Kuzeninin düğünündesin. Avluda davul ve zurna sesi yükseliyor. Dilan yanına geliyor ve: \'Neden yalnız oturuyorsun?\' diyor.',
      choices: [
        StoryChoice(
          labelKu: 'Rojbaş Dilan! Ez hinekî fedî dikim, kesî nas nakim.',
          labelTr: 'Günaydın Dilan! Biraz utanıyorum, kimseyi tanımıyorum.',
          nextNodeId: 'nasin',
          feedbackKu: 'Dilpakiya te hevaltiyeke nû ava dike.',
          feedbackTr: 'İçtenliğin yeni bir arkadaşlık kurar.',
        ),
        StoryChoice(
          labelKu: 'Silav! Ez tenê temaşeya govendê dikim.',
          labelTr: 'Selam! Sadece halay oyununu izliyorum.',
          nextNodeId: 'temase',
          feedbackKu: 'Temaşekirina reqsê jî kêfxweşiyek e.',
          feedbackTr: 'Dansı izlemek de bir keyiftir.',
        ),
      ],
    ),
    const StoryNode(
      id: 'nasin',
      textKu:
          'Dilan bi ken dibêje: \'Xem neke, em hemû heval in! Were em bi hev re herin nav govendê!\'',
      textTr:
          'Dilan gülerek: \'Merak etme, hepimiz arkadaşız! Gel beraber halaya girelim!\' diyor.',
      choices: [
        StoryChoice(
          labelKu: 'Ez govendê pir nizanim, tu dikarî nîşanî min bidî?',
          labelTr: 'Halayı pek bilmiyorum, bana gösterebilir misin?',
          nextNodeId: 'end_govend',
          feedbackKu: 'Xwestina fêrbûnê cesaretê dide mirovan.',
          feedbackTr: 'Öğrenmek istemek insana cesaret verir.',
        ),
        StoryChoice(
          labelKu: 'Temam, ez govendê baş dizanim, em herin serê govendê!',
          labelTr: 'Tamam, ben halayı iyi biliyorum, halay başına geçelim!',
          nextNodeId: 'end_sergovend',
          feedbackKu: 'Pêbaweriya te bi xwe û coşa te mirovan şa dikin.',
          feedbackTr: 'Özgüvenin ve coşkun insanları neşelendirir.',
        ),
      ],
    ),
    const StoryNode(
      id: 'temase',
      textKu:
          'Baran jî tê cem we. Destê xwe dirêjî te dike û dibêje: \'Mirov bi lîstinê kêfa dawetê derdixe, were nav me!\'',
      textTr:
          'Baran da yanınıza geliyor. Elini sana uzatıyor ve: \'Düğünün tadı oynayarak çıkar, aramıza gel!\' diyor.',
      choices: [
        StoryChoice(
          labelKu: 'Baş e Baran, bila dilê we neşkê, ez têm!',
          labelTr: 'Pekâlâ Baran, hatırınız kalmasın, geliyorum!',
          nextNodeId: 'end_govend',
          feedbackKu: 'Qebûlkirina vexwendina hevalan civakîbûnê xurt dike.',
          feedbackTr:
              'Arkadaşların davetini kabul etmek sosyalleşmeyi güçlendirir.',
        ),
        StoryChoice(
          labelKu: 'Hûn herin, ez ê piştî çayê werim.',
          labelTr: 'Siz gidin, ben çaydan sonra geleceğim.',
          nextNodeId: 'nasin',
          feedbackKu: 'Girtina bêhnê berî govendê baş e.',
          feedbackTr: 'Halaydan önce soluklanmak iyidir.',
        ),
      ],
    ),
    const StoryNode(
      id: 'end_govend',
      textKu:
          'Dilan destê te digire: \'Du gav ber bi pêş ve, gavek ber bi paş ve!\' Tu zû fêr dibî û heta derengiyê bi ken direqsî.',
      textTr:
          'Dilan elini tutuyor: \'İki adım ileri, bir adım geri!\' Çabucak öğreniyorsun ve geç saatlere kadar gülerek oynuyorsun.',
    ),
    const StoryNode(
      id: 'end_sergovend',
      textKu:
          'Tu diçî serê govendê, destmala rengîn dihejînî û hemû dawetî bi coş temaşeya te dikin. Şeveke pir xweş derbas dibe!',
      textTr:
          'Halayın başına geçiyorsun, renkli mendili sallıyorsun ve tüm davetliler seni coşkuyla izliyor. Çok güzel bir gece geçiyor!',
    ),
  ],
);

final Story newrozStory = Story(
  id: 'newroz',
  titleKu: 'Newroz',
  titleTr: 'Newroz',
  startNodeId: 'start',
  nodes: [
    const StoryNode(
      id: 'start',
      textKu:
          'Îro 21ê Adarê ye, cejna Newrozê ye. Bihar hat! Berfîn û Rojda tên cem te. Berfîn dibêje: \'Newroza te pîroz be! Tu amade yî?\'',
      textTr:
          'Bugün 21 Mart, Newroz bayramı. Bahar geldi! Berfîn ve Rojda yanına geliyorlar. Berfîn: \'Newroz\'un kutlu olsun! Hazır mısın?\' diyor.',
      choices: [
        StoryChoice(
          labelKu:
              'Newroza we jî pîroz be! Ez ê kincên xwe yên kurdî yên herêmî li xwe bikim.',
          labelTr:
              'Sizin de Newroz\'unuz kutlu olsun! Ben yöresel Kürt kıyafetlerimi giyeceğim.',
          nextNodeId: 'kinc',
          feedbackKu: 'Kincên rengîn bedewiyê li cejnê zêde dikin.',
          feedbackTr: 'Renkli kıyafetler bayrama güzellik katar.',
        ),
        StoryChoice(
          labelKu: 'Pîroz be! Min ji bo hevalan fêkî û xwarin amade kirine.',
          labelTr: 'Kutlu olsun! Arkadaşlar için meyve ve yiyecek hazırladım.',
          nextNodeId: 'xwarin',
          feedbackKu: 'Parvekirina xwarinê dilên mirovan nêzî hev dike.',
          feedbackTr:
              'Yiyecek paylaşmak insanların gönüllerini birbirine yaklaştırır.',
        ),
      ],
    ),
    const StoryNode(
      id: 'kinc',
      textKu:
          'Tu kincên xwe yên rengîn li xwe dikî. Rojda dibêje: \'Gelek li te hatin! Niha em ber bi qada Newrozê ve herin?\'',
      textTr:
          'Renkli kıyafetlerini giyiyorsun. Rojda: \'Çok yakıştı! Şimdi Newroz alanına doğru gidelim mi?\' diyor.',
      choices: [
        StoryChoice(
          labelKu: 'Erê, em bimeşin û hewaya biharê bikişînin nav xwe.',
          labelTr: 'Evet, yürüyelim ve bahar havasını içimize çekelim.',
          nextNodeId: 'qada_cejne',
          feedbackKu: 'Tu bi hevalan re ber bi qadê ve dimeşî.',
          feedbackTr: 'Arkadaşlarla birlikte alana doğru yürüyorsun.',
        ),
      ],
    ),
    const StoryNode(
      id: 'xwarin',
      textKu:
          'Berfîn pakêta xwarinê digire: \'Destên te sax bin! Em ê li deştê xwarina xwe bixwin. Werin em herin.\'',
      textTr:
          'Berfîn yiyecek paketini alıyor: \'Eline sağlık! Kırda yemeğimizi yeriz. Gelin gidelim.\'',
      choices: [
        StoryChoice(
          labelKu: 'Em bi lez herin, heval li benda me ne!',
          labelTr: 'Hızlı gidelim, arkadaşlar bizi bekliyor!',
          nextNodeId: 'qada_cejne',
          feedbackKu: 'Tu dixwazî zû bigihîjî hevalan.',
          feedbackTr: 'Arkadaşlara çabuk ulaşmak istiyorsun.',
        ),
      ],
    ),
    const StoryNode(
      id: 'qada_cejne',
      textKu:
          'Hûn digihîjin qadê. Li navendê agirekî mezin ê Newrozê hatiye pêxistin. Ronahî û germahî li her derê belav dibin.',
      textTr:
          'Meydana varıyorsunuz. Ortada büyük Newroz ateşi yakılmış. Işık ve sıcaklık her yana yayılıyor.',
      choices: [
        StoryChoice(
          labelKu: 'Werin em li dora agirî govendê bigirin!',
          labelTr: 'Gelin ateşin etrafında halay tutalım!',
          nextNodeId: 'end_agir_govend',
          feedbackKu: 'Lîstina li dora agirî nîşaneya hatina biharê ye.',
          feedbackTr: 'Ateş etrafında oyun baharın gelişinin simgesidir.',
        ),
        StoryChoice(
          labelKu: 'Werin em rûnin û hêviyên xwe yên nû parve bikin.',
          labelTr: 'Gelin oturalım ve yeni umutlarımızı paylaşalım.',
          nextNodeId: 'end_hevi',
          feedbackKu: 'Newroz ji bo hêviyên nû yên jiyanê destpêk e.',
          feedbackTr: 'Newroz hayata dair yeni umutlar için bir başlangıçtır.',
        ),
      ],
    ),
    const StoryNode(
      id: 'end_agir_govend',
      textKu:
          'Hûn hemû bi hev re destên hev digirin û bi coş li dora agirê biharê govendê dilîzin. Cejna we pîroz be!',
      textTr:
          'Hepiniz el ele tutuşup bahar ateşi etrafında coşkuyla halay çekiyorsunuz. Bayramınız kutlu olsun!',
    ),
    const StoryNode(
      id: 'end_hevi',
      textKu:
          'Hûn li bin dara kesk rûdinin, xwarina xwe parve dikin û ji bo pêşerojê hêviyên xwe yên xweş tînin ziman. Roja we bi şahî diqede.',
      textTr:
          'Yeşil ağacın altında oturup yemeğinizi paylaşıyor ve gelecek için güzel dileklerde bulunuyorsunuz. Gününüz neşeyle sona eriyor.',
    ),
  ],
);

final Story mevanStory = Story(
  id: 'mevan',
  titleKu: 'Mêvan li malê',
  titleTr: 'Evde misafir',
  startNodeId: 'start',
  nodes: [
    const StoryNode(
      id: 'start',
      textKu:
          'Tu li malê rûniştî yî. Li derî tê xistin. Hevalê te Azad û dayika wî hatine mala we. Tu derî vedikî. Tu çi dibêjî?',
      textTr:
          'Evde oturuyorsun. Kapı çalıyor. Arkadaşın Azad ve annesi evinize gelmiş. Kapıyı açıyorsun. Ne diyorsun?',
      choices: [
        StoryChoice(
          labelKu: 'Hûn bi xêr hatin, kerem bikin werin hundir!',
          labelTr: 'Hoş geldiniz, içeri buyrun!',
          nextNodeId: 'sala_mevan',
          feedbackKu: 'Ev pêşwaziyeke pir germ, rêzdar û guncaw e.',
          feedbackTr: 'Bu çok sıcak, saygılı ve ortama uygun bir karşılamadır.',
        ),
        StoryChoice(
          labelKu: 'Silav Azad, zû were odeya min!',
          labelTr: 'Selam Azad, çabuk odama gel!',
          nextNodeId: 'sala_mevan_lez',
          feedbackKu:
              'Dema mezin li wir bin, silavdayîna herduyan û vexwendina wan bo salonê xweştir e.',
          feedbackTr:
              'Büyükler varken ikisini birden selamlayıp salona buyur etmek daha hoştur.',
        ),
      ],
    ),
    const StoryNode(
      id: 'sala_mevan',
      textKu:
          'Azad û dayika wî derbasî salonê dibin û rûdinin. Tu dixwazî ji bo wan tiştekî amade bikî. Tu çi pêşkêş dikî?',
      textTr:
          'Azad ve annesi salona geçip oturuyorlar. Onlar için bir şey hazırlamak istiyorsun. Ne ikram edersin?',
      choices: [
        StoryChoice(
          labelKu: 'Hûn çayê vedixwin an qehweyê?',
          labelTr: 'Çay mı içersiniz yoksa kahve mi?',
          nextNodeId: 'ikram_ca',
          feedbackKu: 'Ji bo mêvanan pirsiyareke pir xweş û mêvandost e.',
          feedbackTr: 'Misafirler için çok güzel ve misafirperver bir sorudur.',
        ),
        StoryChoice(
          labelKu: 'Ez tenê qedehek av bînim?',
          labelTr: 'Sadece bir bardak su getireyim mi?',
          nextNodeId: 'ikram_av',
          feedbackKu:
              'Av baş e, lê pêşkêşkirina çayê an qehweyê di çanda me de kevneşopiyeke berbelavtir e.',
          feedbackTr:
              'Su iyidir, fakat çay veya kahve teklif etmek kültürümüzde daha yaygın bir gelenektir.',
        ),
      ],
    ),
    const StoryNode(
      id: 'sala_mevan_lez',
      textKu:
          'Azad dikene û dibêje: \'Hevalê min, pêşî em li cem dayika min hinekî rûnin.\' Hûn bi hev re derbasî salonê dibin.',
      textTr:
          'Azad gülümseyip: \'Arkadaşım, önce annemin yanında biraz oturalım\' diyor. Birlikte salona geçiyorsunuz.',
      choices: [
        StoryChoice(
          labelKu:
              'Rast e, kerem bikin werin salonê! Ez ji we re çay amade bikim?',
          labelTr: 'Doğru, salona buyrun! Size çay hazırlayayım mı?',
          nextNodeId: 'ikram_ca',
          feedbackKu: 'Tu niha her du mêvanan vedixwînî salonê.',
          feedbackTr: 'Şimdi iki misafiri de salona davet ediyorsun.',
        ),
      ],
    ),
    const StoryNode(
      id: 'ikram_ca',
      textKu:
          'Dayika Azad dibêje: \'Spas, delalê min, çay dê pir baş be.\' Tu bi lez diçî metbexê, çay û şîranî tînî.',
      textTr:
          'Azad\'ın annesi: \'Teşekkürler yavrum, çay çok iyi olur\' diyor. Çabucak mutfağa gidip çay ve tatlı getiriyorsun.',
      choices: [
        StoryChoice(
          labelKu:
              'Noşî can be! Hûn her dem dikarin werin, ser seran û ser çavan.',
          labelTr:
              'Afiyet olsun! Her zaman gelebilirsiniz, başım gözüm üstüne.',
          nextNodeId: 'end_xwes',
          feedbackKu: 'Ev gotineke pir hêja û dilsoz a mêvanperweriyê ye.',
          feedbackTr:
              'Misafirperverliğin çok değerli ve samimi bir ifadesidir.',
        ),
      ],
    ),
    const StoryNode(
      id: 'ikram_av',
      textKu:
          'Dayika Azad dibêje: \'Spas, lê heke çay hebe em ê pir kêfxweş bibin.\' Tu dibêjî: \'Ser çavan!\' û diçî çayê çêdikî.',
      textTr:
          'Azad\'ın annesi: \'Teşekkürler ama çay varsa çok seviniriz\' diyor. Sen baş üstüne deyip çay demlemeye gidiyorsun.',
      choices: [
        StoryChoice(
          labelKu: 'Ser çavan, ez niha çayeke germ tînim!',
          labelTr: 'Baş üstüne, hemen sıcak bir çay getiriyorum!',
          nextNodeId: 'end_caya_germ',
          feedbackKu: 'Tu daxwaza mêvanan bi kêfxweşî qebûl dikî.',
          feedbackTr: 'Misafirlerin isteğini memnuniyetle kabul ediyorsun.',
        ),
      ],
    ),
    const StoryNode(
      id: 'end_xwes',
      textKu:
          'Hûn bi hev re çay vedixwin, qala dibistanê dikin û dikenin. Mêvan ji awayê pêşwazîkirina te û mêvandariya te pir razî dibin.',
      textTr:
          'Birlikte çay içip okuldan konuşuyor ve gülüyorsunuz. Misafirler karşılamandan ve misafirperverliğinden çok memnun kalıyor.',
    ),
    const StoryNode(
      id: 'end_caya_germ',
      textKu:
          'Tu çaya germ tînî. Dayika Azad spasiya te dike. Hûn çay vedixwin û li wêneyên malbatê dinêrin.',
      textTr:
          'Sıcak çayı getiriyorsun. Azad\'ın annesi sana teşekkür ediyor. Çay içiyor ve aile fotoğraflarına bakıyorsunuz.',
    ),
  ],
);

final Story xwaringehStory = Story(
  id: 'xwaringeh',
  titleKu: 'Li xwaringehê',
  titleTr: 'Lokantada',
  startNodeId: 'start',
  nodes: [
    const StoryNode(
      id: 'start',
      textKu:
          'Tu û hevala te Berfîn diçin xwaringehekê. Hûn li dora maseyekê rûdinin. Garson tê cem we û dibêje: \'Hûn bi xêr hatin! Hûn çi dixwazin?\'',
      textTr:
          'Sen ve arkadaşın Berfîn bir lokantaya gidiyorsunuz. Bir masaya oturuyorsunuz. Garson yanınıza gelip: \'Hoş geldiniz! Ne istersiniz?\' diyor.',
      choices: [
        StoryChoice(
          labelKu: 'Ji bo me lîsteya xwarinan bîne, ji kerema xwe re.',
          labelTr: 'Bizim için yemek menüsünü getir lütfen.',
          nextNodeId: 'siparis_menu',
          feedbackKu:
              'Berî biryardanê dîtina vebijarkan helwesteke pir asayî û biaqil e.',
          feedbackTr:
              'Karar vermeden önce seçenekleri görmek gayet olağan ve akıllıca bir tutumdur.',
        ),
        StoryChoice(
          labelKu: 'Ji bo her yekî ji me porsiyonek goşt û birinc bîne.',
          labelTr: 'İkimiz için de birer porsiyon et ve pilav getir.',
          nextNodeId: 'siparis_birinc',
          feedbackKu:
              'Siparîşeke zelal e, lê pirskirina ji hevala xwe jî dikare fikreke baş be.',
          feedbackTr:
              'Net bir sipariş, fakat arkadaşına da sormak iyi bir fikir olabilir.',
        ),
      ],
    ),
    const StoryNode(
      id: 'siparis_menu',
      textKu:
          'Garson lîsteya xwarinan datîne ser maseyê. Berfîn dibêje: \'Ez ê seleteyekê û şorbeyekê bixwim.\' Tu çi dixwazî bixwî?',
      textTr:
          'Garson menüyü masaya bırakıyor. Berfîn: \'Ben bir salata ve çorba yiyeceğim\' diyor. Sen ne yemek istiyorsun?',
      choices: [
        StoryChoice(
          labelKu: 'Ji min re jî şorbeya nîskê û ava fêkiyan bîne.',
          labelTr: 'Bana da mercimek çorbası ve meyve suyu getir.',
          nextNodeId: 'xwarin_xwes',
          feedbackKu: 'Tu şorbeyê û ava fêkiyan dixwazî.',
          feedbackTr: 'Çorba ve meyve suyu istiyorsun.',
        ),
        StoryChoice(
          labelKu: 'Ji kerema xwe ji min re goştê biraştî û dew bîne.',
          labelTr: 'Lütfen bana ızgara et ve ayran getir.',
          nextNodeId: 'xwarin_xwes',
          feedbackKu: 'Tu bi nermî goşt û dew dixwazî.',
          feedbackTr: 'Nazikçe et ve ayran istiyorsun.',
        ),
      ],
    ),
    const StoryNode(
      id: 'siparis_birinc',
      textKu:
          'Berfîn dibêje: \'Hilbijartineke pir baş e, ez jî birçî bûbûm!\' Garson dibêje: \'Ser çavan, ez di cih de amade dikim.\'',
      textTr:
          'Berfîn: \'Çok iyi bir seçim, ben de acıkmıştım!\' diyor. Garson: \'Baş üstüne, hemen hazırlıyorum\' diyor.',
      choices: [
        StoryChoice(
          labelKu: 'Spas dikim, em li benda xwarinê ne.',
          labelTr: 'Teşekkür ederim, yemeği bekliyoruz.',
          nextNodeId: 'xwarin_xwes',
          feedbackKu: 'Tu spasiya garsonî dikî û li bendê dimînî.',
          feedbackTr: 'Garsona teşekkür ediyor ve bekliyorsun.',
        ),
      ],
    ),
    const StoryNode(
      id: 'xwarin_xwes',
      textKu:
          'Xwarinên germ tên ser maseyê. Hûn bi kêf dixwin û têr dibin. Niha dema dayîna hesabê ye. Tu gazî garson dikî.',
      textTr:
          'Sıcak yemekler masaya geliyor. Keyifle yiyorsunuz ve karnınız doyuyor. Şimdi hesap ödeme zamanı. Garsona sesleniyorsun.',
      choices: [
        StoryChoice(
          labelKu: 'Hesab ji kerema xwe re! Ez dixwazim bidim.',
          labelTr: 'Hesap lütfen! Ben ödemek istiyorum.',
          nextNodeId: 'hesab_yek',
          feedbackKu: 'Daxwazkirina hesabê bi vî rengî pir nazik û zelal e.',
          feedbackTr: 'Hesabı bu şekilde istemek çok nazik ve nettir.',
        ),
        StoryChoice(
          labelKu: 'Gelo em dikarin hesabî cuda cuda bidin?',
          labelTr: 'Acaba hesabı ayrı ayrı ödeyebilir miyiz?',
          nextNodeId: 'hesab_veqeti',
          feedbackKu:
              'Di nav hevalan de parvekirina hesabê daxwazeke pir xwezayî ye.',
          feedbackTr:
              'Arkadaşlar arasında hesabı bölüşmek çok doğal bir taleptir.',
        ),
      ],
    ),
    const StoryNode(
      id: 'hesab_yek',
      textKu:
          'Berfîn dibêje: \'Spas hevalê min, cara din dora min e!\' Garson tê, tu pereyê xwarinê didî.',
      textTr:
          'Berfîn: \'Teşekkürler arkadaşım, bir dahaki sefere sıra bende!\' diyor. Garson geliyor, yemek parasını ödüyorsun.',
      choices: [
        StoryChoice(
          labelKu: 'Destên we sax bin, xwarin pir xweş bû. Xatirê te!',
          labelTr: 'Elinize sağlık, yemek çok güzeldi. Hoşça kal!',
          nextNodeId: 'end_xwaringeh',
          feedbackKu: 'Spasîkirina kedkaran tevgereke pir xweşik e.',
          feedbackTr:
              'Emek verenlere teşekkür etmek çok güzel bir davranıştır.',
        ),
      ],
    ),
    const StoryNode(
      id: 'hesab_veqeti',
      textKu:
          'Garson dibêje: \'Belê, çawa hûn bixwazin.\' Garson hesabê we cuda dike. Hûn her yek para xwe didin.',
      textTr:
          'Garson: \'Evet, nasıl isterseniz\' diyor. Garson hesabınızı ayırıyor. Her biriniz kendi payını ödüyor.',
      choices: [
        StoryChoice(
          labelKu: 'Spas ji bo xizmeta we, roja we bi xêr be!',
          labelTr: 'Hizmetiniz için teşekkürler, iyi günler!',
          nextNodeId: 'end_hesab_cuda',
          feedbackKu: 'Tu bi spasî û silavekê ji garsonî xatirê xwe dixwazî.',
          feedbackTr: 'Teşekkür ve selamla garsona veda ediyorsun.',
        ),
      ],
    ),
    const StoryNode(
      id: 'end_xwaringeh',
      textKu:
          'Hûn bi rûkenî ji xwaringehê derdikevin. Hûn hem têr bûne hem jî dema we bi hevaltiyeke xweş derbas bûye.',
      textTr:
          'Güler yüzle lokantadan çıkıyorsunuz. Hem karnınız doydu hem de vaktiniz güzel bir arkadaşlıkla geçti.',
    ),
    const StoryNode(
      id: 'end_hesab_cuda',
      textKu:
          'Garson bi ken dibêje: \'Roja we jî bi xêr be!\' Tu û Berfîn ji xwaringehê derdikevin û bi hev re ber bi malê ve dimeşin.',
      textTr:
          'Garson gülümseyerek: \'Size de iyi günler!\' diyor. Sen ve Berfîn lokantadan çıkıyor ve birlikte eve doğru yürüyorsunuz.',
    ),
  ],
);

final Story telefonStory = Story(
  id: 'telefon',
  titleKu: 'Telefonkirina hevalekî',
  titleTr: 'Bir arkadaşın telefonu',
  startNodeId: 'start',
  nodes: [
    const StoryNode(
      id: 'start',
      textKu:
          'Telefona te lê dide. Li ser ekranê navê \'Şêrko\' nivîsandî ye. Tu telefonê vedikî. Tu çawa silav didî?',
      textTr:
          'Telefonun çalıyor. Ekranda \'Şêrko\' ismi yazıyor. Telefonu açıyorsun. Nasıl selam verirsin?',
      choices: [
        StoryChoice(
          labelKu: 'Alo Şêrko, rojbaş! Tu çawa yî?',
          labelTr: 'Alo Şêrko, iyi günler! Nasılsın?',
          nextNodeId: 'pirsa_rojev',
          feedbackKu: 'Destpêkeke pir samîmî, nerm û rojane ye.',
          feedbackTr: 'Çok samimi, nazik ve gündelik bir başlangıçtır.',
        ),
        StoryChoice(
          labelKu: 'Silav hevalê min! Çi nûçe, çi heye çi tune?',
          labelTr: 'Selam arkadaşım! Ne haber, ne var ne yok?',
          nextNodeId: 'pirsa_rojev',
          feedbackKu: 'Di nav hevalên nêzîk de gotineke gelekî germ e.',
          feedbackTr: 'Yakın arkadaşlar arasında oldukça sıcak bir ifadedir.',
        ),
      ],
    ),
    const StoryNode(
      id: 'pirsa_rojev',
      textKu:
          'Şêrko dibêje: \'Spas, ez baş im! Îro hewa pir xweş û tavî ye. Tu vala yî ku em derkevin derve?\' Tu çi dibêjî?',
      textTr:
          'Şêrko: \'Teşekkürler, iyiyim! Bugün hava çok güzel ve güneşli. Dışarı çıkmak için müsait misin?\' diyor. Ne diyorsun?',
      choices: [
        StoryChoice(
          labelKu: 'Belê, fikreke pir xweş e! Em li ku derê hev bibînin?',
          labelTr: 'Evet, çok güzel bir fikir! Nerede buluşalım?',
          nextNodeId: 'cih_hilbijartin',
          feedbackKu: 'Bersiveke erênî û zelal e.',
          feedbackTr: 'Olumlu ve net bir cevaptır.',
        ),
        StoryChoice(
          labelKu:
              'Niha hinek karê min heye, lê ez dikarim piştî nîvro derkevim derve.',
          labelTr: 'Şu an biraz işim var ama öğleden sonra yapabilirim.',
          nextNodeId: 'dem_dereng',
          feedbackKu: 'Diyarkirina dema xwe ya guncaw pir baş e.',
          feedbackTr: 'Kendine uygun zamanı belirtmek çok iyidir.',
        ),
      ],
    ),
    const StoryNode(
      id: 'dem_dereng',
      textKu:
          'Şêrko dibêje: \'Pir baş e, nexwe di saet sêyan (15:00) de ji bo te çawa ye?\' Tu dibêjî: \'Pir baş e.\' Niha divê hûn ciyê hevdîtinê diyar bikin.',
      textTr:
          'Şêrko: \'Çok iyi, öyleyse saat üçte (15:00) senin için nasıl?\' diyor. Sen: \'Çok iyi\' diyorsun. Şimdi buluşma yerini belirlemelisiniz.',
      choices: [
        StoryChoice(
          labelKu: 'Temam, em li ku derê bicivin?',
          labelTr: 'Tamam, nerede buluşalım?',
          nextNodeId: 'cih_hilbijartin',
          feedbackKu: 'Tu niha ciyê hevdîtinê dipirsî.',
          feedbackTr: 'Şimdi buluşma yerini soruyorsun.',
        ),
      ],
    ),
    const StoryNode(
      id: 'cih_hilbijartin',
      textKu:
          'Şêrko dipirse: \'Em biçin parka bajêr an li qehwexaneya li navendê rûnin?\' Tu kîjan derê hildibijêrî?',
      textTr:
          'Şêrko soruyor: \'Şehir parkına mı gidelim yoksa merkezdeki kafede mi oturalım?\' Sen nereyi seçiyorsun?',
      choices: [
        StoryChoice(
          labelKu: 'Ka em herin parkê, em ê hem bimeşin hem jî biaxivin.',
          labelTr: 'Hadi parka gidelim, hem yürürüz hem konuşuruz.',
          nextNodeId: 'end_telefon',
          feedbackKu: 'Ji bo hewaya xweş vebijarkeke pir tendurist û xweş e.',
          feedbackTr: 'Güzel hava için çok sağlıklı ve güzel bir tercihtir.',
        ),
        StoryChoice(
          labelKu: 'Em herin qehwexaneyê, çayek vexwin û rûnin.',
          labelTr: 'Kafeye gidelim, bir çay içip oturalım.',
          nextNodeId: 'end_qehwexane',
          feedbackKu: 'Ji bo rûniştin û sohbetê ciyekî pir aram e.',
          feedbackTr: 'Oturup sohbet etmek için çok sakin bir yerdir.',
        ),
      ],
    ),
    const StoryNode(
      id: 'end_telefon',
      textKu:
          'Şêrko dibêje: \'Em li hev hatin! Wê demê em di saet sêyan de li wir in. Xatirê te!\' Tu jî dibêjî: \'Bi saxî bimîne!\' û bi kêfxweşî telefonê digirî.',
      textTr:
          'Şêrko: \'Anlaştık! O zaman saat üçte oradayız. Hoşça kal!\' diyor. Sen de \'Sağlıcakla kal\' deyip neşeyle telefonu kapatıyorsun.',
    ),
    const StoryNode(
      id: 'end_qehwexane',
      textKu:
          'Şêrko dibêje: \'Temam, em li qehwexaneyê hev bibînin. Bi xatirê te!\' Tu telefonê dadixî. Dû re hûn li qehwexaneyê çay vedixwin û diaxivin.',
      textTr:
          'Şêrko: \'Tamam, kafede buluşalım. Hoşça kal!\' diyor. Telefonu kapatıyorsun. Daha sonra kafede çay içip konuşuyorsunuz.',
    ),
  ],
);

final Story dibistanStory = Story(
  id: 'dibistan',
  titleKu: 'Roja yekem li dibistanê',
  titleTr: 'Okulda ilk gün',
  startNodeId: 'start',
  nodes: [
    const StoryNode(
      id: 'start',
      textKu:
          'Îro roja te ya yekem e li dibistana nû. Tu hinekî bi kelecan î. Tu dikevî polê. Keçikek li kêleka kursiyeke vala rûniştiye. Tu çi dikî?',
      textTr:
          'Bugün yeni okuldaki ilk günün. Biraz heyecanlısın. Sınıfa giriyorsun. Bir kız boş bir sandalyenin yanında oturuyor. Ne yaparsın?',
      choices: [
        StoryChoice(
          labelKu: 'Silav, gelo ev der vala ye? Ez dikarim li vir rûnim?',
          labelTr: 'Selam, acaba burası boş mu? Buraya oturabilir miyim?',
          nextNodeId: 'nasina_zelal',
          feedbackKu: 'Pirsiyareke pir bi edeb û rêzdar e.',
          feedbackTr: 'Çok terbiyeli ve saygılı bir sorudur.',
        ),
        StoryChoice(
          labelKu: 'Rojbaş hevalê! Ez îro di vê polê de nû me.',
          labelTr: 'İyi günler arkadaşım! Ben bugün bu sınıfta yeniyim.',
          nextNodeId: 'nasina_zelal',
          feedbackKu: 'Nasandina xwe di gava yekem de destpêkeke wêrek e.',
          feedbackTr: 'Kendini ilk adımda tanıtmak cesur bir başlangıçtır.',
        ),
      ],
    ),
    const StoryNode(
      id: 'nasina_zelal',
      textKu:
          'Keçik bi ken li te dinêre û dibêje: \'Silav! Belê vala ye, kerem bike rûne. Navê min Zelal e. Tu bi xêr hatî dibistana me!\' Tu çawa bersiv didî?',
      textTr:
          'Kız gülümseyerek sana bakıp: \'Selam! Evet boş, buyur otur. Benim adım Zelal. Okulumuza hoş geldin!\' diyor. Sen nasıl cevap verirsin?',
      choices: [
        StoryChoice(
          labelKu: 'Spas Zelal, ez bi nasîna te pir kêfxweş bûm.',
          labelTr: 'Teşekkürler Zelal, seninle tanıştığıma çok memnun oldum.',
          nextNodeId: 'ders_destpeke',
          feedbackKu: 'Hevokeke bingehîn û gelekî nazik a hevdunasînê ye.',
          feedbackTr: 'Tanışmada kullanılan çok temel ve kibar bir cümledir.',
        ),
        StoryChoice(
          labelKu: 'Gelo mamosteyê me yê yekem kî ye? Dersa me çi ye?',
          labelTr: 'İlk öğretmenimiz kim acaba? Dersimiz ne?',
          nextNodeId: 'ders_destpeke',
          feedbackKu:
              'Pirsîna li ser polê û dersê meraqeke xwezayî nîşan dide.',
          feedbackTr:
              'Sınıf ve ders hakkında soru sormak doğal bir merak göstergesidir.',
        ),
      ],
    ),
    const StoryNode(
      id: 'ders_destpeke',
      textKu:
          'Zelal dibêje: \'Dersa me ya yekem ziman e. Mamoste Baran mirovekî pir baş û lihevborî ye.\' Di wê gavê de mamoste dikeve polê û dibêje: \'Rojbaş hevalno!\'',
      textTr:
          'Zelal: \'İlk dersimiz dil. Baran Öğretmen çok iyi ve hoşgörülü biridir\' diyor. O anda öğretmen sınıfa girip: \'İyi günler arkadaşlar!\' diyor.',
      choices: [
        StoryChoice(
          labelKu:
              'Tevî hevalan rabe ser piyan û bibêje: \'Rojbaş mamosteyê min!\'',
          labelTr:
              'Arkadaşlarla birlikte ayağa kalk ve: \'İyi günler öğretmenim!\' de.',
          nextNodeId: 'bersiva_mamoste',
          feedbackKu:
              'Bi vî rengî rêz nîşanî mamoste dan kevneşopiyeke dibistanê ye.',
          feedbackTr:
              'Öğretmene bu şekilde saygı göstermek bir okul geleneğidir.',
        ),
        StoryChoice(
          labelKu: 'Li cihê xwe bimîne û hêdîka bibêje: \'Hûn bi xêr hatin.\'',
          labelTr: 'Yerinde kal ve sessizce: \'Hoş geldiniz\' de.',
          nextNodeId: 'bersiva_mamoste',
          feedbackKu:
              'Bi tevahiya polê re rabûn aheng û rêzdariyê zêdetir dike.',
          feedbackTr:
              'Bütün sınıfla birlikte ayağa kalkmak uyumu ve saygıyı pekiştirir.',
        ),
      ],
    ),
    const StoryNode(
      id: 'bersiva_mamoste',
      textKu:
          'Mamoste Baran pirtûkên xwe datîne ser maseyê, li te dinêre û dikene: \'Hevalekî me yê nû heye! Tu dikarî xwe bi kurtî bidî nasîn?\'',
      textTr:
          'Baran Öğretmen kitaplarını masaya koyuyor, sana bakıp gülümsüyor: \'Yeni bir arkadaşımız var! Kendini kısaca tanıtabilir misin?\'',
      choices: [
        StoryChoice(
          labelKu: 'Ez bi kêfxweşî hatime vir û dixwazim hevalên nû nas bikim.',
          labelTr:
              'Buraya memnuniyetle geldim ve yeni arkadaşlar tanımak istiyorum.',
          nextNodeId: 'end_dibistan',
          feedbackKu: 'Peyameke pir germ û dostane ye.',
          feedbackTr: 'Çok sıcak ve dostça bir mesajdır.',
        ),
        StoryChoice(
          labelKu: 'Ez hinekî bi kelecan im, lê min pir ji vê polê hez kir.',
          labelTr: 'Biraz heyecanlıyım ama bu sınıfı çok sevdim.',
          nextNodeId: 'end_zelal',
          feedbackKu: 'Parvekirina hestên xwe bi awayekî dilpak pir xweş e.',
          feedbackTr: 'Duygularını içtenlikle paylaşmak çok güzeldir.',
        ),
      ],
    ),
    const StoryNode(
      id: 'end_dibistan',
      textKu:
          'Mamoste Baran dibêje: \'Tu bi xêr hatî nava me! Em ê bi hev re dersên xweş bixwînin.\' Zelal jî destê xwe datîne ser milê te û dikene. Kelecana te derbas dibe û roja te pir xweş dest pê dike.',
      textTr:
          'Baran Öğretmen: \'Aramıza hoş geldin! Birlikte güzel dersler işleyeceğiz\' diyor. Zelal de omzuna dokunup gülümsüyor. Heyecanın geçiyor ve günün çok güzel başlıyor.',
    ),
    const StoryNode(
      id: 'end_zelal',
      textKu:
          'Mamoste Baran dibêje: \'Tu bi xêr hatî!\' Tu li kêleka Zelalê rûdinî. Ew pirtûka xwe bi te re parve dike û hûn bi hev re dersê dixwînin.',
      textTr:
          'Baran Öğretmen: \'Hoş geldin!\' diyor. Zelal\'in yanına oturuyorsun. O kitabını seninle paylaşıyor ve birlikte ders çalışıyorsunuz.',
    ),
  ],
);

final List<Story> moreEverydayStories = [
  bijiskStory,
  otobusStory,
  dawetStory,
  newrozStory,
  mevanStory,
  xwaringehStory,
  telefonStory,
  dibistanStory,
];
