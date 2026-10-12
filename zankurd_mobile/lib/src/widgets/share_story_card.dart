import 'package:flutter/material.dart';

import '../config/category_visuals.dart';
import '../l10n/lang.dart';
import '../l10n/strings.dart';
import '../theme/app_theme.dart';
import 'roj_mascot.dart';
import 'sahne/sahne.dart';

/// Paylaşım görseli biçimi: hikâye (1080×1920) ya da kare (1080×1080).
enum ShareCardFormat {
  story(1080, 1920),
  square(1080, 1080);

  const ShareCardFormat(this.width, this.height);
  final double width;
  final double height;
}

/// Sosyal ağda paylaşılan sonuç görseli (büyüme yüzeyi).
///
/// Eski uygulama içi küçük kartın (360 geniş, 2026-10-12 silindi) yerine; hikâye
/// ve kare ölçüsünde, uzaktan okunur boyutta çizilir: logo, konunun kilim
/// bandı, büyük skor, yıldız, tek cümle ve site adresi. Mantıksal boyut
/// piksel boyuttur (pixelRatio 1). İki temada da gece sahnesidir.
class ShareStoryCard extends StatelessWidget {
  const ShareStoryCard({
    required this.isKu,
    required this.format,
    required this.scoreText,
    required this.category,
    this.stars = 3,
    this.duelWin = false,
    this.scoreLabel,
    super.key,
  });

  final bool isKu;
  final ShareCardFormat format;

  /// "9/10" ya da "240".
  final String scoreText;

  /// "puan" gibi skorun altındaki künye; yoksa çizilmez.
  final String? scoreLabel;

  /// Kurmancî kategori kimliği ([CategoryNames]).
  final String category;
  final int stars;
  final bool duelWin;

  static const siteLink = 'zankurd.com';

  @override
  Widget build(BuildContext context) {
    return SahneStage(
      stage: AppTheme.stage,
      child: Builder(builder: _build),
    );
  }

  Widget _build(BuildContext context) {
    final t = SahneTokens.of(context);
    final story = format == ShareCardFormat.story;
    final mark = CategoryVisuals.mark(category);
    final tone = CategoryVisuals.tone(category);
    final line = duelWin
        ? Tr.forKu(K.shareStoryDuelWin, isKu)
        : Tr.forKu(K.shareStoryLine, isKu, {'score': scoreText});

    Widget band() {
      if (mark == null) return const SizedBox.shrink();
      // 9 hücre × 12 px = 108 px kare; sekiz karo yan yana kilim şeridi.
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < 8; i++)
            SizedBox.square(
              dimension: 108,
              child: CustomPaint(
                painter: SahneKilimBandPainter(
                  mark: mark,
                  tone: tone,
                  reservedWidth: 108,
                ),
              ),
            ),
        ],
      );
    }

    final gap = story ? 72.0 : 36.0;
    return SizedBox(
      width: format.width,
      height: format.height,
      child: CustomPaint(
        painter: SahneStagePainter(
          race: false,
          glow: t.roleGlow(SahneRole.gold),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            72,
            story ? 120 : 64,
            72,
            story ? 120 : 64,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  BrandMarkPlate(size: story ? 96 : 72),
                  const SizedBox(width: 24),
                  Text(
                    'ZanKurd',
                    style: SahneType.screen.copyWith(
                      color: t.tx,
                      fontSize: story ? 64 : 52,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              band(),
              SizedBox(height: gap / 2),
              Center(
                child: DecoratedBox(
                  decoration: ShapeDecoration(color: t.s2, shape: SahneShape.m),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40,
                      vertical: 16,
                    ),
                    child: Text(
                      CategoryNames.localized(category, isKu),
                      style: SahneType.headline.copyWith(
                        color: t.tx,
                        fontSize: 40,
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: gap),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  scoreText,
                  style: SahneType.screen.copyWith(
                    color: t.gold,
                    fontSize: story ? 280 : 200,
                    height: 1,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              if (scoreLabel != null)
                Text(
                  scoreLabel!,
                  textAlign: TextAlign.center,
                  style: SahneType.headline.copyWith(
                    color: t.tx2,
                    fontSize: 44,
                  ),
                ),
              SizedBox(height: gap),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var i = 0; i < 3; i++) ...[
                    if (i > 0) const SizedBox(width: 24),
                    SahneGlyph(
                      SahneGlyphKind.star,
                      size: (i == 1 ? 120.0 : 88.0) * (story ? 1 : 0.8),
                      filled: i < stars,
                    ),
                  ],
                ],
              ),
              SizedBox(height: gap),
              Text(
                line,
                textAlign: TextAlign.center,
                style: SahneType.headline.copyWith(
                  color: t.tx,
                  fontSize: story ? 58 : 48,
                  height: 1.25,
                ),
              ),
              const Spacer(),
              Text(
                siteLink,
                textAlign: TextAlign.center,
                style: SahneType.headline.copyWith(
                  color: t.goldTx,
                  fontSize: 52,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
