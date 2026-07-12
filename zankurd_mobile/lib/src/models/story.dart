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
          feedbackKu: 'Xwezî! Bijartineke nazik.',
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
      textKu: 'Xizmetkar bişirîn dike: "Baş e, her tu bixwazî bang bike."',
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
