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

  const Friend({
    required this.id,
    required this.userId,
    required this.friendId,
    required this.friendName,
    this.friendAvatarColor,
    required this.createdAt,
  });

  Friend copyWith({
    String? id,
    String? userId,
    String? friendId,
    String? friendName,
    String? friendAvatarColor,
    DateTime? createdAt,
  }) => Friend(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    friendId: friendId ?? this.friendId,
    friendName: friendName ?? this.friendName,
    friendAvatarColor: friendAvatarColor ?? this.friendAvatarColor,
    createdAt: createdAt ?? this.createdAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'friend_id': friendId,
    'friend_name': friendName,
    'friend_avatar_color': friendAvatarColor,
    'created_at': createdAt.toIso8601String(),
  };

  static Friend fromJson(Map<String, dynamic> json) => Friend(
    id: json['id'] as String,
    userId: json['user_id'] as String,
    friendId: json['friend_id'] as String,
    friendName: json['friend_name'] as String,
    friendAvatarColor: json['friend_avatar_color'] as String?,
    createdAt: DateTime.parse(json['created_at'] as String),
  );

  @override
  String toString() => 'Friend(id: $id, friend: $friendName)';
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
    toUserId: json['to_user_id'] as String,
    createdAt: DateTime.parse(json['created_at'] as String),
    status: json['status'] as String? ?? 'pending',
  );

  @override
  String toString() => 'FriendRequest(from: $fromUserName, status: $status)';
}
