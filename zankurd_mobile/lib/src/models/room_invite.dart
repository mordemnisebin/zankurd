import 'package:flutter/foundation.dart';

/// Bir arkadaşın beni odasına davet etmesi (`list_my_room_invites`).
///
/// Sunucu yalnız lobisi hâlâ açık, 30 dakikadan yeni ve engelsiz davetleri
/// döndürür. [roomCode] KAPALI bir dizgedir: istemci biçimini bilmez, yalnız
/// mevcut katılma yoluna (`joinOnlineRoom`) verir.
@immutable
class RoomInvite {
  const RoomInvite({
    required this.id,
    required this.roomId,
    required this.roomCode,
    required this.inviterId,
    required this.inviterName,
    required this.categoryName,
    required this.playerCount,
    required this.maxPlayers,
    required this.createdAt,
  });

  final String id;
  final String roomId;
  final String roomCode;
  final String inviterId;
  final String inviterName;
  final String categoryName;
  final int playerCount;
  final int maxPlayers;
  final DateTime createdAt;

  static RoomInvite fromJson(Map<String, dynamic> json) => RoomInvite(
    id: json['invite_id'] as String,
    roomId: json['room_id'] as String,
    roomCode: json['room_code'] as String,
    inviterId: json['inviter_id'] as String? ?? '',
    inviterName: json['inviter_name'] as String? ?? 'ZanKurd',
    categoryName: json['category_name'] as String? ?? '',
    playerCount: (json['player_count'] as num?)?.toInt() ?? 1,
    maxPlayers: (json['max_players'] as num?)?.toInt() ?? 2,
    createdAt:
        DateTime.tryParse(json['created_at'] as String? ?? '') ??
        DateTime.now(),
  );

  @override
  String toString() => 'RoomInvite($inviterName -> $roomCode)';
}

/// Oda davetinin ayırt edilen hata sebepleri; arayüz bunları yerelleştirir.
enum RoomInviteFailure {
  /// Davet süresi doldu, geri alındı ya da oda lobisi kapandı.
  expired,

  /// Oda dolu.
  full,

  /// Saatlik davet sınırı.
  tooMany,

  /// Tanınmayan hata (ağ vb.): yanlış kesinlik iddia edilmez.
  unknown,
}

class RoomInviteException implements Exception {
  const RoomInviteException(this.reason, [this.message]);

  final RoomInviteFailure reason;
  final String? message;

  /// Sunucunun düz metin `raise exception` mesajını sebebe eşler.
  static RoomInviteFailure reasonForMessage(String message) {
    if (message.contains('Invite expired') ||
        message.contains('Invite not found') ||
        message.contains('Room not found')) {
      return RoomInviteFailure.expired;
    }
    if (message.contains('Room is full')) return RoomInviteFailure.full;
    if (message.contains('Too many')) return RoomInviteFailure.tooMany;
    return RoomInviteFailure.unknown;
  }

  @override
  String toString() => 'RoomInviteException($reason, $message)';
}
