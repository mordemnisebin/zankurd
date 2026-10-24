import 'package:flutter/foundation.dart';

import 'public_profile.dart';

/// Oda sohbet mesajı.
@immutable
class RoomMessage {
  final String id;
  final String roomId;
  final String senderId;
  final String senderName;
  final String? senderAvatarColor;
  final String text;
  final DateTime createdAt;

  /// Göndericinin güncel herkese açık kimliği (fotoğraf/simge/kod). Mesaj
  /// satırı yalnız gönderim anındaki ad ve rengi taşır; depo bunu tamamlar.
  final PublicProfile? senderProfile;

  const RoomMessage({
    required this.id,
    required this.roomId,
    required this.senderId,
    required this.senderName,
    this.senderAvatarColor,
    required this.text,
    required this.createdAt,
    this.senderProfile,
  });

  /// Güncel profille tamamlanmış kopya (ad boşsa mesajdaki ad kalır).
  RoomMessage withProfile(PublicProfile? profile) {
    if (profile == null) return this;
    return RoomMessage(
      id: id,
      roomId: roomId,
      senderId: senderId,
      senderName: profile.nameOr(senderName),
      senderAvatarColor: profile.avatar.colorHex ?? senderAvatarColor,
      text: text,
      createdAt: createdAt,
      senderProfile: profile,
    );
  }

  static RoomMessage fromJson(Map<String, dynamic> json) => RoomMessage(
    id: json['id'] as String,
    roomId: json['room_id'] as String,
    senderId: json['sender_id'] as String,
    senderName: json['sender_name'] as String? ?? 'Oyuncu',
    senderAvatarColor: json['sender_avatar_color'] as String?,
    text: json['text'] as String,
    createdAt:
        DateTime.tryParse(json['created_at'] as String? ?? '') ??
        DateTime.now(),
  );

  @override
  String toString() => 'RoomMessage(id: $id, sender: $senderName, text: $text)';
}
