import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../config/avatar_presets.dart';
import '../game/avatar_frames.dart';
import '../models/avatar_identity.dart';
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
    this.showcaseTitle,
    this.displayName,
    this.colorSeed,
    this.colorOverride,
    this.imageProviderFactory,
    super.key,
  });

  /// Ortak kimlik nesnesinden ([AvatarIdentity]) kurar: oyuncu listelerinin
  /// hepsi (lobi, sıralama, 1v1, arkadaşlar, davet, düello) aynı yolu
  /// kullanır. Öncelik yine fotoğraf > simge > baş harf; [colorHex] kimlikte
  /// yoksa çağıranın bildiği yedek renk ([fallbackColorHex]) kullanılır.
  ///
  /// [displayName] HAM ad (yer tutucu olabilir) verilir: baş harf/renk
  /// tohumu kuralı [PlayerIdentity] ile bu bileşenin içinde uygulanır.
  factory PlayerAvatar.fromIdentity({
    required double radius,
    AvatarIdentity? identity,
    String? displayName,
    String? fallbackColorHex,
    Color? colorOverride,
    ImageProvider Function(String url)? imageProviderFactory,
    Key? key,
  }) {
    return PlayerAvatar(
      key: key,
      radius: radius,
      photoUrl: identity?.photoUrl,
      iconId: identity?.iconId,
      colorHex: identity?.colorHex ?? fallbackColorHex,
      frameId: identity?.frameId,
      showcaseTitle: identity?.showcaseTitle,
      displayName: displayName,
      colorSeed: PlayerIdentity.resolveColorSeed(displayName),
      colorOverride: colorOverride,
      imageProviderFactory: imageProviderFactory,
    );
  }

  final double radius;
  final String? photoUrl;
  final String? iconId;
  final String? colorHex;
  final String? frameId;

  /// Vitrin unvanı; VIP ise avatarın sağ alt köşesine rozet çizilir
  /// (sıralama, 1v1, oda, eşleşme — her yerde aynı).
  final String? showcaseTitle;
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
    final shape = SahneShape.forSize(size);
    // Çap 20'nin altında çift kontur çekirdeği yok eder; tek halkaya düşer.
    final premium = frame != null && isPremiumFrame(frame) && size >= 20;
    final outer = premiumFrameOuterWidth(size);
    // Premium: dış halka + 1 ayırıcı + 1 iç tel; çekirdek bunların içinde.
    final inset = premium ? outer + 2 : 0.0;
    final coreSize = size - inset * 2;

    final core = ClipPath(
      clipper: ShapeBorderClipper(shape: SahneShape.forSize(coreSize)),
      child: SizedBox.square(
        dimension: coreSize,
        child: _buildCore(context, bg, coreSize),
      ),
    );

    final List<Widget> layers;
    if (premium) {
      Widget fill(double pad, Decoration decoration, {Key? key}) => Padding(
        padding: EdgeInsets.all(pad),
        child: DecoratedBox(key: key, decoration: decoration),
      );
      layers = [
        fill(
          0,
          ShapeDecoration(shape: shape, gradient: premiumFrameGradient(frame)),
          key: const ValueKey('avatar-frame-premium'),
        ),
        fill(
          outer,
          ShapeDecoration(shape: shape, color: premiumFrameSeparator),
        ),
        fill(
          outer + 1,
          ShapeDecoration(shape: shape, color: premiumFrameInner(frame)),
        ),
        Padding(padding: EdgeInsets.all(inset), child: core),
      ];
    } else {
      final ring = frame == null ? t.rim : frameColor(frame);
      layers = [
        core,
        IgnorePointer(
          child: DecoratedBox(
            decoration: ShapeDecoration(
              shape: SahneShape.withSide(
                shape,
                ring,
                width: frame == null ? SahneRing.r1 : SahneRing.r3,
              ),
            ),
          ),
        ),
      ];
    }

    return SizedBox.square(
      key: frame == null ? null : const ValueKey('avatar-frame-ring'),
      dimension: size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ...layers,
          if (isVipTitle(showcaseTitle))
            PositionedDirectional(
              end: 0,
              bottom: 0,
              child: _VipMark(compact: size < 40),
            ),
        ],
      ),
    );
  }

  Widget _buildCore(BuildContext context, Color bg, double size) {
    final url = photoUrl;
    if (url != null && url.trim().isNotEmpty) {
      final base =
          imageProviderFactory?.call(url) ??
          CachedNetworkImageProvider(url) as ImageProvider;
      // Çözme boyutu çizilen boyuta bağlanır: büyük bir kaynak fotoğraf
      // küçük avatar olarak çizilse de tam çözünürlükte belleğe açılırdı
      // (Codex denetimi 2026-10-29).
      final decodePx = (size * MediaQuery.devicePixelRatioOf(context))
          .ceil()
          .clamp(1, 512);
      final provider = ResizeImage(base, width: decodePx);
      // İndirilirken boş kare yerine oyuncunun rengi görünür; hata olursa
      // simge/harf katmanına düşülür (fotoğraf "bozuk resim" çizmez).
      return ColoredBox(
        color: bg,
        child: Image(
          image: provider,
          fit: BoxFit.cover,
          // Fotoğraf süstür: oyuncunun adı yanındaki metindedir.
          excludeFromSemantics: true,
          errorBuilder: (context, error, stack) =>
              _iconOrLetter(context, bg, size),
        ),
      );
    }
    return _iconOrLetter(context, bg, size);
  }

  Widget _iconOrLetter(BuildContext context, Color bg, double size) {
    final icon =
        iconFor(iconId) ??
        (PlayerIdentity.isPlaceholderDisplayName(displayName)
            ? AppIcons.user
            : null);
    final fg = sahneOnFill(bg);
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

/// VIP rozeti: koyu zemin, 1 px altın kenar. Çap ≥ 40'ta "VIP" yazısı,
/// altında yazı okunmaz, altın mücevher simgesi (mağazadaki VIP simgesi).
class _VipMark extends StatelessWidget {
  const _VipMark({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final decoration = ShapeDecoration(
      color: premiumFrameSeparator,
      shape: SahneShape.withSide(SahneShape.s, AppTheme.gold, width: 1),
    );
    return Semantics(
      label: 'VIP',
      child: Container(
        key: const ValueKey('avatar-vip-badge'),
        width: compact ? 11 : 24,
        height: compact ? 11 : 13,
        alignment: Alignment.center,
        decoration: decoration,
        child: compact
            ? const Icon(AppIcons.gem, size: 7, color: AppTheme.gold)
            : const Text(
                'VIP',
                maxLines: 1,
                textScaler: TextScaler.noScaling,
                style: TextStyle(
                  color: AppTheme.gold,
                  fontSize: 8,
                  height: 1,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                ),
              ),
      ),
    );
  }
}
