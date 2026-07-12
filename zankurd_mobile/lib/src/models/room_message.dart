import 'package:flutter/foundation.dart';

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

  const RoomMessage({
    required this.id,
    required this.roomId,
    required this.senderId,
    required this.senderName,
    this.senderAvatarColor,
    required this.text,
    required this.createdAt,
  });

  static RoomMessage fromJson(Map<String, dynamic> json) => RoomMessage(
    id: json['id'] as String,
    roomId: json['room_id'] as String,
    senderId: json['sender_id'] as String,
    senderName: json['sender_name'] as String? ?? 'Oyuncu',
    senderAvatarColor: json['sender_avatar_color'] as String?,
    text: json['text'] as String,
    createdAt: DateTime.parse(json['created_at'] as String),
  );

  @override
  String toString() => 'RoomMessage(id: $id, sender: $senderName, text: $text)';
}
