class Player {
  /// Oyuncunun odada hazır olduğunu bildiren `state` değeri.
  ///
  /// `state` serbest bir gösterim dizesidir (`'Bot'`, `'Cevapladı'`, `'—'`
  /// de olabilir), bu yüzden hazırlık bilgisi ayrı bir alan değil bu
  /// dizenin bir değeri olarak taşınıyor. Karşılaştırma birden çok yerde
  /// yapıldığı için sabit burada durur: bir dosyada 'Hazır' yazımı
  /// değişirse diğerleri sessizce yanlış cevap vermeye başlardı.
  static const readyState = 'Hazır';

  const Player({
    this.id,
    required this.name,
    required this.score,
    required this.state,
    this.streak = 0,
    this.avatarIcon,
    this.avatarColor,
    this.avatarUrl,
    this.avatarFrame,
    this.showcaseTitle,
  });

  final String? id;
  final String name;
  final int score;
  final String state;
  final int streak;

  // Kozmetik vitrin alanları (1v1/oda ekranlarında rakip avatarı için);
  // sunucu döndürmediğinde null kalır, baş-harf avatarına düşülür.
  final String? avatarIcon;
  final String? avatarColor;
  final String? avatarUrl;
  final String? avatarFrame;
  final String? showcaseTitle;

  Player copyWith({
    String? id,
    String? name,
    int? score,
    String? state,
    int? streak,
  }) {
    return Player(
      id: id ?? this.id,
      name: name ?? this.name,
      score: score ?? this.score,
      state: state ?? this.state,
      streak: streak ?? this.streak,
      avatarIcon: avatarIcon,
      avatarColor: avatarColor,
      avatarUrl: avatarUrl,
      avatarFrame: avatarFrame,
      showcaseTitle: showcaseTitle,
    );
  }
}

String? _usablePlayerId(String? id) {
  final normalized = id?.trim();
  return normalized == null || normalized.isEmpty ? null : normalized;
}

/// [player] ile hedef kimlik aynı oyuncuyu mu temsil ediyor?
///
/// Taraflardan herhangi birinde kalıcı kimlik varsa ad hiç dikkate
/// alınmaz; eşleşme için iki kimliğin de bulunup aynı olması gerekir. Ad
/// karşılaştırması yalnız iki tarafın da kimliksiz olduğu eski oda ve
/// broadcast kayıtları için geriye uyumluluk yoludur.
bool playerMatchesIdentity(
  Player player, {
  required String? id,
  required String legacyName,
}) {
  final playerId = _usablePlayerId(player.id);
  final targetId = _usablePlayerId(id);
  if (playerId != null || targetId != null) {
    return playerId != null && targetId != null && playerId == targetId;
  }
  return player.name == legacyName;
}

/// İki oyuncu kaydı aynı kimliğe mi ait?
bool playersShareIdentity(Player first, Player second) {
  return playerMatchesIdentity(first, id: second.id, legacyName: second.name);
}

/// Cevap/hazır durumları gibi geçici haritalar için çakışmasız anahtar.
String playerIdentityKey({required String? id, required String legacyName}) {
  final usableId = _usablePlayerId(id);
  return usableId == null ? 'name:$legacyName' : 'id:$usableId';
}
