import 'avatar_identity.dart';

/// Başka bir oyuncunun herkese açık kimliği: ad, oyuncu kodu ve avatar.
///
/// `profiles` RLS'si yalnız kendi satırını okutur; başkasının adı/fotoğrafı
/// `get_public_profiles` RPC'siyle gelir. Liste RPC'lerinin çoğu (arkadaşlar,
/// istekler, davetler, oda sonucu, sıralama) ya yalnız ad ya da hiçbir kimlik
/// alanı döndürmüyor; depo, id'si bilinen oyuncuları bu nesneyle tamamlar ve
/// ekranlar tek bir kural/bileşenle çizer (`PlayerAvatar.forProfile`,
/// `PlayerIdentity.resolveNameWithTag`).
class PublicProfile {
  const PublicProfile({
    required this.id,
    this.displayName,
    this.playerTag,
    this.avatar = const AvatarIdentity(),
  });

  final String id;
  final String? displayName;
  final String? playerTag;
  final AvatarIdentity avatar;

  static PublicProfile fromJson(Map<String, dynamic> row) => PublicProfile(
    id: row['id'] as String,
    displayName: row['display_name'] as String?,
    playerTag: row['player_tag'] as String?,
    avatar: AvatarIdentity(
      iconId: row['avatar_icon'] as String?,
      colorHex: row['avatar_color'] as String?,
      photoUrl: row['avatar_url'] as String?,
      frameId: row['avatar_frame'] as String?,
      showcaseTitle: row['showcase_title'] as String?,
    ),
  );

  /// Sunucudan gelen ad boş değilse onu, değilse [fallback]'i verir.
  String nameOr(String fallback) {
    final name = displayName?.trim() ?? '';
    return name.isEmpty ? fallback : name;
  }
}
