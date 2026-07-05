import 'package:flutter/material.dart';

import '../config/avatar_presets.dart';
import '../game/avatar_frames.dart';
import '../theme/app_theme.dart';

/// Oyuncu avatarının TEK görsel kaynağı. Öncelik sırası:
/// fotoğraf (photoUrl) > hazır ikon (iconId) > adın baş harfi.
/// Fotoğraf yüklenemezse otomatik olarak ikon/harf katmanına düşer.
/// [frameId] doluysa kazanılmış çerçeve halkası çizilir.
class PlayerAvatar extends StatelessWidget {
  const PlayerAvatar({
    required this.radius,
    this.photoUrl,
    this.iconId,
    this.colorHex,
    this.frameId,
    this.displayName,
    this.imageProviderFactory,
    super.key,
  });

  final double radius;
  final String? photoUrl;
  final String? iconId;
  final String? colorHex;
  final String? frameId;
  final String? displayName;

  /// Testlerde ağ görüntüsü yerine sahte provider enjekte etmek için.
  /// null ise NetworkImage kullanılır.
  final ImageProvider Function(String url)? imageProviderFactory;

  @override
  Widget build(BuildContext context) {
    final bg = colorFrom(colorHex, fallback: AppTheme.accent);
    final frame = frameFromId(frameId);

    Widget core = _buildCore(bg);

    core = SizedBox(
      width: radius * 2,
      height: radius * 2,
      child: ClipOval(child: core),
    );

    if (frame == null) return core;

    final ring = frameColor(frame);
    return Container(
      key: const ValueKey('avatar-frame-ring'),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [ring, ring.withValues(alpha: 0.55)],
        ),
        boxShadow: [
          BoxShadow(color: ring.withValues(alpha: 0.35), blurRadius: 8),
        ],
      ),
      child: core,
    );
  }

  Widget _buildCore(Color bg) {
    final url = photoUrl;
    if (url != null && url.trim().isNotEmpty) {
      final provider =
          imageProviderFactory?.call(url) ?? NetworkImage(url) as ImageProvider;
      return Image(
        image: provider,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stack) => _iconOrLetter(bg),
      );
    }
    return _iconOrLetter(bg);
  }

  Widget _iconOrLetter(Color bg) {
    final icon = iconFor(iconId);
    return ColoredBox(
      color: bg,
      child: Center(
        child: icon != null
            ? Icon(icon, color: Colors.white, size: radius * 1.05)
            : Text(
                (displayName?.trim().isNotEmpty == true
                        ? displayName!.trim()[0]
                        : 'Z')
                    .toUpperCase(),
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: radius * 0.85,
                ),
              ),
      ),
    );
  }
}
