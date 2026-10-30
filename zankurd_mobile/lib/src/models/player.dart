import 'public_profile.dart';

class Player {
  /// Oyuncunun odada hazır olduğunu bildiren `state` değeri.
  ///
  /// `state` serbest bir gösterim dizesidir (`'Bot'`, `'Cevapladı'`, `'—'`
  /// de olabilir), bu yüzden hazırlık bilgisi ayrı bir alan değil bu
  /// dizenin bir değeri olarak taşınıyor. Karşılaştırma birden çok yerde
  /// yapıldığı için sabit burada durur: bir dosyada 'Hazır' yazımı
  /// değişirse diğerleri sessizce yanlış cevap vermeye başlardı.
  static const readyState = 'Hazır';

  /// Cihazda üretilen bot rakibin `state` değeri (`BotRace.toPlayers`).
  static const botState = 'Bot';

  const Player({
    this.id,
    this.joinedAt,
    required this.name,
    required this.score,
    required this.state,
    this.streak = 0,
    this.avatarIcon,
    this.avatarColor,
    this.avatarUrl,
    this.avatarFrame,
    this.showcaseTitle,
    this.tag,
    this.rank,
    this.left = false,
  });

  final String? id;

  /// Oda sırası için sunucunun room_players.joined_at değeri.
  final DateTime? joinedAt;
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

  /// Oyuncu kodu (`profiles.player_tag`); adsız oyuncuda "Oyuncu ZK-XXXX".
  final String? tag;

  /// Kalabalık odanın sunucu sıralaması (1'den başlar; eşit skor aynı sırayı
  /// paylaşır). Yalnız sonuç yükünde gelir; ayrılan oyuncuda ve eski
  /// (1v1) odalarda `null`.
  final int? rank;

  /// Kalabalık odada oyun sürerken ayrılan ya da hazır olmadığı için düşen
  /// oyuncu (`room_players.left_at` dolu). Satır silinmez: skoru kalır,
  /// ama sıralamaya girmez ve oda onu beklemez.
  final bool left;

  /// Rakip cihazdaki bot mu (gerçek oyuncu değil)? Arayüz bunu "Bot"
  /// rozetiyle açıkça söyler (2026-10-29, X4).
  bool get isBot => state == botState;

  /// Herkese açık profille tamamlanmış kopya: boş/yer tutucu olmayan ad,
  /// fotoğraf, simge, renk, çerçeve, unvan ve oyuncu kodu profilden gelir.
  /// Profil yoksa aynı oyuncu döner.
  Player withProfile(PublicProfile? profile) {
    if (profile == null) return this;
    final profileName = profile.displayName?.trim() ?? '';
    final a = profile.avatar;
    return Player(
      id: id,
      joinedAt: joinedAt,
      name: profileName.isEmpty ? name : profileName,
      score: score,
      state: state,
      streak: streak,
      avatarIcon: a.iconId ?? avatarIcon,
      avatarColor: a.colorHex ?? avatarColor,
      avatarUrl: a.photoUrl ?? avatarUrl,
      avatarFrame: a.frameId ?? avatarFrame,
      showcaseTitle: a.showcaseTitle ?? showcaseTitle,
      tag: profile.playerTag ?? tag,
      rank: rank,
      left: left,
    );
  }

  /// Aynı oyuncunun [other] kaydındaki kimlik alanlarıyla zenginleştirilmiş
  /// kopyası (canlı skor akışı eski, kimliği eksik kaydı ezmesin diye).
  Player mergeIdentity(Player other) => Player(
    id: id ?? other.id,
    joinedAt: joinedAt ?? other.joinedAt,
    name: name,
    score: score,
    state: state,
    streak: streak,
    avatarIcon: other.avatarIcon ?? avatarIcon,
    avatarColor: other.avatarColor ?? avatarColor,
    avatarUrl: other.avatarUrl ?? avatarUrl,
    avatarFrame: other.avatarFrame ?? avatarFrame,
    showcaseTitle: other.showcaseTitle ?? showcaseTitle,
    tag: other.tag ?? tag,
    rank: rank,
    left: left,
  );

  Player copyWith({
    String? id,
    String? name,
    int? score,
    String? state,
    int? streak,
    int? rank,
    bool? left,
  }) {
    return Player(
      id: id ?? this.id,
      joinedAt: joinedAt,
      name: name ?? this.name,
      score: score ?? this.score,
      state: state ?? this.state,
      streak: streak ?? this.streak,
      avatarIcon: avatarIcon,
      avatarColor: avatarColor,
      avatarUrl: avatarUrl,
      avatarFrame: avatarFrame,
      showcaseTitle: showcaseTitle,
      tag: tag,
      rank: rank ?? this.rank,
      left: left ?? this.left,
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

/// Sunucunun oda katılma anahtarı: zaman, eşitlikte kalıcı oyuncu kimliği.
int compareRoomPlayerOrder(
  DateTime? firstJoinedAt,
  String? firstId,
  DateTime? secondJoinedAt,
  String? secondId,
) {
  if (firstJoinedAt != null && secondJoinedAt != null) {
    final byJoin = firstJoinedAt.compareTo(secondJoinedAt);
    if (byJoin != 0) return byJoin;
  } else if (firstJoinedAt != null || secondJoinedAt != null) {
    return firstJoinedAt == null ? 1 : -1;
  }
  return (firstId ?? '').compareTo(secondId ?? '');
}
