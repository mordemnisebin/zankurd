import 'package:flutter/foundation.dart';

/// Arkadaş ilişkisi — iki oyuncu arasındaki bağlantı
@immutable
class Friend {
  final String id;
  final String userId; // Mevcut oyuncu
  final String friendId; // Arkadaş (diğer oyuncu)
  final String friendName; // Arkadaş adı
  final String? friendAvatarColor; // Arkadaş avatar rengi
  final DateTime createdAt;

  /// Skor / seviye bilgileri (leaderboard ve profile entegrasyonu için).
  final int totalScore;
  final int level;
  final int gamesPlayed;

  /// Son aktiflik zamanı; null ise hiç çevrimiçi olmamış sayılır.
  final DateTime? lastActiveAt;

  const Friend({
    required this.id,
    required this.userId,
    required this.friendId,
    required this.friendName,
    this.friendAvatarColor,
    required this.createdAt,
    this.totalScore = 0,
    this.level = 1,
    this.gamesPlayed = 0,
    this.lastActiveAt,
  });

  /// Son 5 dakika içinde aktifse çevrimiçi sayılır.
  bool get isOnline {
    final last = lastActiveAt;
    if (last == null) return false;
    return DateTime.now().toUtc().difference(last).inMinutes < 5;
  }

  Friend copyWith({
    String? id,
    String? userId,
    String? friendId,
    String? friendName,
    String? friendAvatarColor,
    DateTime? createdAt,
    int? totalScore,
    int? level,
    int? gamesPlayed,
    DateTime? lastActiveAt,
  }) => Friend(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    friendId: friendId ?? this.friendId,
    friendName: friendName ?? this.friendName,
    friendAvatarColor: friendAvatarColor ?? this.friendAvatarColor,
    createdAt: createdAt ?? this.createdAt,
    totalScore: totalScore ?? this.totalScore,
    level: level ?? this.level,
    gamesPlayed: gamesPlayed ?? this.gamesPlayed,
    lastActiveAt: lastActiveAt ?? this.lastActiveAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'friend_id': friendId,
    'friend_name': friendName,
    'friend_avatar_color': friendAvatarColor,
    'created_at': createdAt.toIso8601String(),
    if (totalScore != 0) 'total_score': totalScore,
    if (level != 1) 'level': level,
    if (gamesPlayed != 0) 'games_played': gamesPlayed,
    if (lastActiveAt != null)
      'last_active_at': lastActiveAt!.toUtc().toIso8601String(),
  };

  static Friend fromJson(Map<String, dynamic> json) => Friend(
    id: json['id'] as String,
    userId: json['user_id'] as String,
    friendId: json['friend_id'] as String,
    friendName: json['friend_name'] as String,
    friendAvatarColor: json['friend_avatar_color'] as String?,
    createdAt: DateTime.parse(json['created_at'] as String),
    totalScore: (json['total_score'] as num?)?.toInt() ?? 0,
    level: (json['level'] as num?)?.toInt() ?? 1,
    gamesPlayed: (json['games_played'] as num?)?.toInt() ?? 0,
    lastActiveAt: json['last_active_at'] != null
        ? DateTime.parse(json['last_active_at'] as String)
        : null,
  );

  @override
  String toString() =>
      'Friend(id: $id, friend: $friendName, score: $totalScore)';
}

/// Arkadaş isteği — bekleyen bağlantı
@immutable
class FriendRequest {
  final String id;
  final String fromUserId;
  final String fromUserName;
  final String toUserId;
  final DateTime createdAt;
  final String status; // 'pending', 'accepted', 'rejected'

  const FriendRequest({
    required this.id,
    required this.fromUserId,
    required this.fromUserName,
    required this.toUserId,
    required this.createdAt,
    this.status = 'pending',
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'from_user_id': fromUserId,
    'from_user_name': fromUserName,
    'to_user_id': toUserId,
    'created_at': createdAt.toIso8601String(),
    'status': status,
  };

  static FriendRequest fromJson(Map<String, dynamic> json) => FriendRequest(
    id: json['id'] as String,
    fromUserId: json['from_user_id'] as String,
    fromUserName: json['from_user_name'] as String,
    // list_pending_friend_requests RPC'si to_user_id döndürmez (hep alıcıdır).
    toUserId: json['to_user_id'] as String? ?? '',
    createdAt: DateTime.parse(json['created_at'] as String),
    status: json['status'] as String? ?? 'pending',
  );

  @override
  String toString() => 'FriendRequest(from: $fromUserName, status: $status)';
}

/// Oyuncu arama sonucu (arkadaş ekleme akışı).
@immutable
class PlayerSearchResult {
  final String id;
  final String displayName;
  final String? avatarColor;

  const PlayerSearchResult({
    required this.id,
    required this.displayName,
    this.avatarColor,
  });

  static PlayerSearchResult fromJson(Map<String, dynamic> json) =>
      PlayerSearchResult(
        id: json['id'] as String,
        displayName: json['display_name'] as String? ?? '',
        avatarColor: json['avatar_color'] as String?,
      );

  @override
  String toString() => 'PlayerSearchResult($displayName)';
}
