/// Metin tabanlı, dallanan hikâye modeli (SES YOK — yalnız metin).
///
/// Her düğümde Kurmancî metin ve Türkçe destek açıklaması bulunur. Seçimler
/// bir sonraki düğümü belirler; seçimsiz düğüm bitiştir. Yanlış/doğru yerine
/// bağlama uygun geri bildirim kullanılır ([StoryChoice.feedbackKu]).
library;

class StoryChoice {
  const StoryChoice({
    required this.labelKu,
    required this.labelTr,
    required this.nextNodeId,
    this.feedbackKu,
    this.feedbackTr,
  });

  final String labelKu;
  final String labelTr;
  final String nextNodeId;
  final String? feedbackKu;
  final String? feedbackTr;
}

class StoryNode {
  const StoryNode({
    required this.id,
    required this.textKu,
    required this.textTr,
    this.choices = const [],
  });

  final String id;
  final String textKu;
  final String textTr;
  final List<StoryChoice> choices;

  bool get isEnding => choices.isEmpty;
}

class Story {
  Story({
    required this.id,
    required this.titleKu,
    required this.titleTr,
    required this.startNodeId,
    required List<StoryNode> nodes,
  }) : _nodes = {for (final n in nodes) n.id: n};

  final String id;
  final String titleKu;
  final String titleTr;
  final String startNodeId;
  final Map<String, StoryNode> _nodes;

  Iterable<StoryNode> get nodes => _nodes.values;

  /// Geçersiz id güvenli biçimde null döner (asla exception atmaz).
  StoryNode? node(String? id) => id == null ? null : _nodes[id];

  StoryNode get start => _nodes[startNodeId]!;

  /// Verilen düğümden bir seçim izlenerek ulaşılan geçerli düğüm; seçim veya
  /// hedef geçersizse null (koruma).
  StoryNode? follow(StoryNode from, StoryChoice choice) {
    if (!from.choices.contains(choice)) return null;
    return node(choice.nextNodeId);
  }
}

/// Küçük, günlük ve güvenli bir örnek hikâye: çayxanede sohbet.
/// Karmaşık tarihsel iddia içermez; nazik, bağlamsal geri bildirim kullanır.
final Story cayxaneStory = Story(
  id: 'cayxane',
  titleKu: 'Li Çayxanê',
  titleTr: 'Çay Evinde',
  startNodeId: 'start',
  nodes: [
    const StoryNode(
      id: 'start',
      textKu:
          'Tu dikevî çayxaneyê. Xizmetkar dibêje: "Bi xêr hatî! Tu çi vedixwî?"',
      textTr:
          'Çay evine giriyorsun. Garson diyor ki: "Hoş geldin! Ne içersin?"',
      choices: [
        StoryChoice(
          labelKu: 'Çayekê, ji kerema xwe.',
          labelTr: 'Bir çay, lütfen.',
          nextNodeId: 'tea',
          feedbackKu: 'Xweş! Bijartineke nazik.',
          feedbackTr: 'Güzel! Nazik bir seçim.',
        ),
        StoryChoice(
          labelKu: 'Ez tenê li bendê me.',
          labelTr: 'Sadece bekliyorum.',
          nextNodeId: 'wait',
        ),
      ],
    ),
    const StoryNode(
      id: 'tea',
      textKu: 'Xizmetkar çayê tîne. "Şekir dixwazî?" Tu dibêjî...',
      textTr: 'Garson çayı getiriyor. "Şeker ister misin?" Sen dersin ki...',
      choices: [
        StoryChoice(
          labelKu: 'Belê, spas.',
          labelTr: 'Evet, teşekkürler.',
          nextNodeId: 'end_warm',
        ),
        StoryChoice(
          labelKu: 'Na, sax be.',
          labelTr: 'Hayır, sağ ol.',
          nextNodeId: 'end_warm',
        ),
      ],
    ),
    const StoryNode(
      id: 'wait',
      textKu: 'Xizmetkar dibişire: "Baş e, kengî bixwazî bang bike."',
      textTr: 'Garson gülümsüyor: "Tamam, ne istersen seslen."',
      choices: [
        StoryChoice(
          labelKu: 'Naha çayekê bîne.',
          labelTr: 'Şimdi bir çay getir.',
          nextNodeId: 'tea',
        ),
      ],
    ),
    const StoryNode(
      id: 'end_warm',
      textKu: 'Tu çaya xwe vedixwî û bêhna xwe fireh dikî. Rojeke xweş!',
      textTr: 'Çayını içiyor ve rahatlıyorsun. Güzel bir gün!',
    ),
  ],
);

/// Günlük tanışma: kullanıcı adını söyler, karşısındakini tanır ve vedalaşır.
final Story introducingYourselfStory = Story(
  id: 'xwe-nasandin',
  titleKu: 'Xwe Nasandin',
  titleTr: 'Kendini Tanıtma',
  startNodeId: 'start',
  nodes: [
    const StoryNode(
      id: 'start',
      textKu:
          'Tu li kursê kesekî nû dibînî. Ew dibêje: "Silav! Navê te çi ye?"',
      textTr: 'Kursta yeni biriyle karşılaşıyorsun. "Merhaba! Adın ne?" diyor.',
      choices: [
        StoryChoice(
          labelKu: 'Silav, navê min Rojda ye.',
          labelTr: 'Merhaba, benim adım Rojda.',
          nextNodeId: 'ask_name',
          feedbackKu: 'Tu navê xwe bi awayekî vekirî dibêjî.',
          feedbackTr: 'Adını açık ve doğal biçimde söyledin.',
        ),
        StoryChoice(
          labelKu: 'Ez Rojda me. Tu kî yî?',
          labelTr: 'Ben Rojda. Sen kimsin?',
          nextNodeId: 'meet_berfin',
          feedbackKu: 'Tu hem xwe nasand û hem jî pirs kir.',
          feedbackTr: 'Hem kendini tanıttın hem de soru sordun.',
        ),
      ],
    ),
    const StoryNode(
      id: 'ask_name',
      textKu: 'Ew dibêje: "Ez Berfîn im." Tu dixwazî sohbetê bidomînî.',
      textTr: '"Ben Berfin" diyor. Sohbeti sürdürmek istiyorsun.',
      choices: [
        StoryChoice(
          labelKu: 'Tu ji ku derê yî?',
          labelTr: 'Nerelisin?',
          nextNodeId: 'end_friend',
          feedbackKu: 'Pirseke kurt sohbetê berdewam dike.',
          feedbackTr: 'Kısa bir soru sohbeti sürdürdü.',
        ),
        StoryChoice(
          labelKu: 'Bi dîtina te kêfxweş bûm.',
          labelTr: 'Tanıştığımıza memnun oldum.',
          nextNodeId: 'end_polite',
          feedbackKu: 'Tu sohbetê bi gotineke germ diqedînî.',
          feedbackTr: 'Sohbeti sıcak bir sözle tamamladın.',
        ),
      ],
    ),
    const StoryNode(
      id: 'meet_berfin',
      textKu: 'Ew dibişire: "Ez Berfîn im, ez jî xwendekar im."',
      textTr: 'Gülümsüyor: "Ben Berfin, ben de öğrenciyim."',
      choices: [
        StoryChoice(
          labelKu: 'Bi dîtina te kêfxweş bûm.',
          labelTr: 'Tanıştığımıza memnun oldum.',
          nextNodeId: 'end_polite',
          feedbackKu: 'Tu nasînê bi gotineke dostane diqedînî.',
          feedbackTr: 'Tanışmayı dostça bir sözle tamamladın.',
        ),
      ],
    ),
    const StoryNode(
      id: 'end_friend',
      textKu: 'Berfîn cihê xwe dibêje û hûn bi hev re dikevin dersê.',
      textTr: 'Berfin nereli olduğunu söylüyor ve derse birlikte giriyorsunuz.',
    ),
    const StoryNode(
      id: 'end_polite',
      textKu: 'Berfîn dibêje: "Ez jî kêfxweş bûm. Paşê em hev dibînin."',
      textTr: 'Berfin, "Ben de memnun oldum. Sonra görüşürüz" diyor.',
    ),
  ],
);

/// Küçük bir dükkânda ürün sorma, fiyat öğrenme ve karar verme hikâyesi.
final Story shoppingStory = Story(
  id: 'kirin',
  titleKu: 'Li Dikanê',
  titleTr: 'Alışverişte',
  startNodeId: 'start',
  nodes: [
    const StoryNode(
      id: 'start',
      textKu:
          'Tu dikevî dikanê. Firoşkar dipirse: "Ez dikarim alîkariya te bikim?"',
      textTr:
          'Dükkâna giriyorsun. Satıcı, "Yardım edebilir miyim?" diye soruyor.',
      choices: [
        StoryChoice(
          labelKu: 'Belê, ez nan digerim.',
          labelTr: 'Evet, ekmek arıyorum.',
          nextNodeId: 'bread',
          feedbackKu: 'Tu tiştê ku dixwazî rasterast dibêjî.',
          feedbackTr: 'Aradığın şeyi doğrudan söyledin.',
        ),
        StoryChoice(
          labelKu: 'Ev sêv çend in?',
          labelTr: 'Bu elmalar ne kadar?',
          nextNodeId: 'apples',
          feedbackKu: 'Tu bi "çend" bihayê dipirsî.',
          feedbackTr: 'Fiyatı kısa bir soruyla sordun.',
        ),
      ],
    ),
    const StoryNode(
      id: 'bread',
      textKu: 'Firoşkar nan nîşan dide: "Li vir e. Tiştekî din?"',
      textTr: 'Satıcı ekmeği gösteriyor: "Burada. Başka bir şey?"',
      choices: [
        StoryChoice(
          labelKu: 'Na, spas. Tenê nan.',
          labelTr: 'Hayır, teşekkürler. Yalnızca ekmek.',
          nextNodeId: 'end_bread',
          feedbackKu: 'Tu daxwaza xwe bi zelalî sînordar dikî.',
          feedbackTr: 'İstediğini açıkça sınırlandırdın.',
        ),
      ],
    ),
    const StoryNode(
      id: 'apples',
      textKu: 'Firoşkar bihayê dibêje. Tu biryar didî.',
      textTr: 'Satıcı fiyatı söylüyor. Karar veriyorsun.',
      choices: [
        StoryChoice(
          labelKu: 'Baş e, kîloyekê bidin min.',
          labelTr: 'Tamam, bir kilo verin.',
          nextNodeId: 'end_apples',
          feedbackKu: 'Tu qasê ku dixwazî diyar dikî.',
          feedbackTr: 'İstediğin miktarı belirttin.',
        ),
        StoryChoice(
          labelKu: 'Spas, ez ê hinekî bifikirim.',
          labelTr: 'Teşekkürler, biraz düşüneceğim.',
          nextNodeId: 'end_think',
          feedbackKu: 'Tu biryara xwe bi awayekî nazik dibêjî.',
          feedbackTr: 'Kararını nazikçe ifade ettin.',
        ),
      ],
    ),
    const StoryNode(
      id: 'end_bread',
      textKu: 'Tu nan dikirî û ji dikanê derdikevî.',
      textTr: 'Ekmeği alıp dükkândan çıkıyorsun.',
    ),
    const StoryNode(
      id: 'end_apples',
      textKu: 'Firoşkar sêvan dixe çenteyê. Tu pere didî.',
      textTr: 'Satıcı elmaları poşete koyuyor. Ödeme yapıyorsun.',
    ),
    const StoryNode(
      id: 'end_think',
      textKu: 'Tu bi aramî ji dikanê derdikevî.',
      textTr: 'Sakince dükkândan çıkıyorsun.',
    ),
  ],
);

/// Sokakta yön sorma ve verilen kısa tarifi takip etme hikâyesi.
final Story askingDirectionsStory = Story(
  id: 'rê-pirsîn',
  titleKu: 'Rê Pirsîn',
  titleTr: 'Yol Sorma',
  startNodeId: 'start',
  nodes: [
    const StoryNode(
      id: 'start',
      textKu: 'Tu li kolanê yî û pirtûkxaneyê digerî. Tu ji kesekî dipirsî...',
      textTr: 'Sokaktasın ve kütüphaneyi arıyorsun. Birine soruyorsun...',
      choices: [
        StoryChoice(
          labelKu: 'Bibore, pirtûkxane li ku ye?',
          labelTr: 'Affedersiniz, kütüphane nerede?',
          nextNodeId: 'directions',
          feedbackKu: 'Tu bi "bibore" dest bi pirsê dikî.',
          feedbackTr: 'Soruya nazik bir giriş yaptın.',
        ),
        StoryChoice(
          labelKu: 'Ez pirtûkxaneyê digerim. Tu dizanî li ku ye?',
          labelTr: 'Kütüphaneyi arıyorum. Nerede olduğunu biliyor musunuz?',
          nextNodeId: 'landmark',
          feedbackKu: 'Tu armanca xwe dibêjî û alîkariyê dixwazî.',
          feedbackTr: 'Amacını açıklayıp yardım istedin.',
        ),
      ],
    ),
    const StoryNode(
      id: 'directions',
      textKu: 'Ew dibêje: "Rast here, paşê li çepê bizivire."',
      textTr: '"Düz git, sonra sola dön" diyor.',
      choices: [
        StoryChoice(
          labelKu: 'Spas! Ez ê rast herim.',
          labelTr: 'Teşekkürler! Düz gideceğim.',
          nextNodeId: 'end_arrive',
          feedbackKu: 'Tu rêya yekem dubare dikî û piştrast dibî.',
          feedbackTr: 'İlk yönü tekrar ederek anladığını gösterdin.',
        ),
        StoryChoice(
          labelKu: 'Li kêleka parkê ye?',
          labelTr: 'Parkın yanında mı?',
          nextNodeId: 'end_confirm',
          feedbackKu: 'Tu bi nîşaneke cihî rêyê piştrast dikî.',
          feedbackTr: 'Bir yer işaretiyle tarifi netleştirdin.',
        ),
      ],
    ),
    const StoryNode(
      id: 'landmark',
      textKu: 'Ew dibêje: "Belê, li kêleka parkê ye."',
      textTr: '"Evet, parkın yanında" diyor.',
      choices: [
        StoryChoice(
          labelKu: 'Gelek spas, min dît.',
          labelTr: 'Çok teşekkürler, gördüm.',
          nextNodeId: 'end_confirm',
          feedbackKu: 'Tu dibêjî ku cih dîtî û spas dikî.',
          feedbackTr: 'Yeri gördüğünü söyleyip teşekkür ettin.',
        ),
      ],
    ),
    const StoryNode(
      id: 'end_arrive',
      textKu: 'Tu rêyê dişopînî û digihîjî pirtûkxaneyê.',
      textTr: 'Tarifi takip edip kütüphaneye ulaşıyorsun.',
    ),
    const StoryNode(
      id: 'end_confirm',
      textKu: 'Tu parkê dibînî û pirtûkxane li kêleka wê ye.',
      textTr: 'Parkı görüyorsun; kütüphane hemen yanında.',
    ),
  ],
);

/// Sıra sabittir; eski çayxane ilk sırada ve aynı kimlikle kalır.
final List<Story> everydayStories = [
  cayxaneStory,
  introducingYourselfStory,
  shoppingStory,
  askingDirectionsStory,
];
