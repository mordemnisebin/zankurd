import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../config/avatar_presets.dart';
import '../game/avatar_frames.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';
import '../utils/player_identity.dart';
import 'sahne/sahne.dart';

/// Oyuncu avatarının TEK görsel kaynağı. Öncelik sırası:
/// fotoğraf (photoUrl) > hazır ikon (iconId) > adın baş harfi.
/// Fotoğraf yüklenemezse otomatik olarak ikon/harf katmanına düşer.
/// [frameId] doluysa kazanılmış çerçeve halkası çizilir.
///
/// 2026-09-29 Şahnê: avatar dili [SahneAvatar] ile ortak. Kutu `radius * 2`
/// karedir (çağıranların yerleşimi değişmez); fotoğraf boyuna uygun pahlı
/// kareyle ([SahneShape.forSize]) kırpılır, yoksa seçilen renkte pahlı kare
/// + ikon ya da baş harf.
///
/// 2026-09-29 doğallık (K5): avatar eskiden elmastı. Elmas aynı anda
/// avatar, ilerleme, sayaç, rozet ve yol düğümüydü; hiçbir şey anlatmıyordu
/// ve fotoğrafın yarısını kesiyordu. Elmas yalnız soru ilerlemesi ve ders
/// sayacında kalır.
/// Ön plan rengi dolguya göre karşıtlıkla seçilir ([sahneOnFill]); sabit
/// beyaz değil. Kazanılmış çerçeve Halka 3 olarak içe çizilir (madalya
/// dili); çerçevesiz avatarda nötr kaş (Halka 1). Bulanık gölge yok.
class PlayerAvatar extends StatelessWidget {
  const PlayerAvatar({
    required this.radius,
    this.photoUrl,
    this.iconId,
    this.colorHex,
    this.frameId,
    this.displayName,
    this.colorSeed,
    this.colorOverride,
    this.imageProviderFactory,
    super.key,
  });

  final double radius;
  final String? photoUrl;
  final String? iconId;
  final String? colorHex;
  final String? frameId;
  final String? displayName;

  /// Renk hash'inin tohumu. Verilmezse [displayName] kullanılır.
  ///
  /// Ayrı bir alan çünkü gösterilen ad DİLE göre değişebiliyor (yer tutucu
  /// adlarda «Oyuncu»/«Lîstikvan») ve renk onunla birlikte kaymamalı —
  /// bkz. `PlayerIdentity.resolveColorSeed`.
  final String? colorSeed;

  /// 2026-07-23 M25b: aynı ekranda render edilen oyuncular arasındaki hash
  /// çakışmasını çözmek için çağıran taraf ([resolveAvatarColors]) bu
  /// alanla hesaplanmış rengi zorlayabilir. `colorHex`'ten bile önceliklidir
  /// çünkü yalnızca `colorHex == null` girdiler için hesaplanır — bu
  /// nedenle ikisi asla aynı anda anlamlı şekilde çakışmaz.
  final Color? colorOverride;

  /// Testlerde ağ görüntüsü yerine sahte provider enjekte etmek için.
  /// null ise NetworkImage kullanılır.
  final ImageProvider Function(String url)? imageProviderFactory;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    // Renk önceliği: kullanıcının seçtiği hex > isim-hash paleti. Bu renk
    // kullanıcının kimliğidir (belirteç değil, veri); olduğu gibi boyanır.
    final bg =
        colorOverride ??
        (colorHex != null
            ? colorFrom(colorHex, fallback: AppTheme.accent)
            : avatarColorForName(colorSeed ?? displayName));
    final frame = frameFromId(frameId);
    final size = radius * 2;

    final core = ClipPath(
      clipper: ShapeBorderClipper(shape: SahneShape.forSize(size)),
      child: SizedBox.square(dimension: size, child: _buildCore(context, bg)),
    );

    final ring = frame == null ? t.rim : frameColor(frame);
    return SizedBox.square(
      key: frame == null ? null : const ValueKey('avatar-frame-ring'),
      dimension: size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          core,
          IgnorePointer(
            child: DecoratedBox(
              decoration: ShapeDecoration(
                shape: SahneShape.withSide(
                  SahneShape.forSize(size),
                  ring,
                  width: frame == null ? SahneRing.r1 : SahneRing.r3,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCore(BuildContext context, Color bg) {
    final url = photoUrl;
    if (url != null && url.trim().isNotEmpty) {
      final provider =
          imageProviderFactory?.call(url) ??
          CachedNetworkImageProvider(url) as ImageProvider;
      return Image(
        image: provider,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stack) => _iconOrLetter(context, bg),
      );
    }
    return _iconOrLetter(context, bg);
  }

  Widget _iconOrLetter(BuildContext context, Color bg) {
    final icon =
        iconFor(iconId) ??
        (PlayerIdentity.isPlaceholderDisplayName(displayName)
            ? AppIcons.user
            : null);
    final fg = sahneOnFill(bg);
    final size = radius * 2;
    final name = displayName?.trim();
    final initial = SahneType.upperFor(
      name != null && name.isNotEmpty ? name[0] : 'Z',
      isKu: sahneIsKu(context),
    );
    return ColoredBox(
      color: bg,
      child: Center(
        // Pahlı karenin iç alanı geniştir: ikon kenarın yarısı, harf %60'ı.
        child: icon != null
            ? Icon(icon, color: fg, size: size * 0.5)
            : SizedBox.square(
                dimension: size * 0.6,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    initial,
                    maxLines: 1,
                    style: SahneType.headline.copyWith(color: fg, height: 1),
                  ),
                ),
              ),
      ),
    );
  }
}
