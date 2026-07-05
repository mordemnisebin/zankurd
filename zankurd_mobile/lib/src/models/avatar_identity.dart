/// Oyuncunun görsel kimliği: hazır ikon+renk, yüklenen fotoğraf, kazanılmış
/// çerçeve ve vitrin unvanı. Tüm alanlar kozmetiktir ve nullable'dır; boş
/// kimlik baş-harf avatarına düşer (bkz. PlayerAvatar).
class AvatarIdentity {
  const AvatarIdentity({
    this.iconId,
    this.colorHex,
    this.photoUrl,
    this.frameId,
    this.showcaseTitle,
  });

  final String? iconId;
  final String? colorHex;
  final String? photoUrl;
  final String? frameId;
  final String? showcaseTitle;

  AvatarIdentity copyWith({
    String? iconId,
    String? colorHex,
    String? photoUrl,
    String? frameId,
    String? showcaseTitle,
    bool clearPhoto = false,
    bool clearFrame = false,
    bool clearTitle = false,
  }) {
    return AvatarIdentity(
      iconId: iconId ?? this.iconId,
      colorHex: colorHex ?? this.colorHex,
      photoUrl: clearPhoto ? null : (photoUrl ?? this.photoUrl),
      frameId: clearFrame ? null : (frameId ?? this.frameId),
      showcaseTitle: clearTitle ? null : (showcaseTitle ?? this.showcaseTitle),
    );
  }

  Map<String, dynamic> toJson() => {
    'icon_id': iconId,
    'color_hex': colorHex,
    'photo_url': photoUrl,
    'frame_id': frameId,
    'showcase_title': showcaseTitle,
  };

  factory AvatarIdentity.fromJson(Map<String, dynamic> json) {
    return AvatarIdentity(
      iconId: json['icon_id'] as String?,
      colorHex: json['color_hex'] as String?,
      photoUrl: json['photo_url'] as String?,
      frameId: json['frame_id'] as String?,
      showcaseTitle: json['showcase_title'] as String?,
    );
  }
}
