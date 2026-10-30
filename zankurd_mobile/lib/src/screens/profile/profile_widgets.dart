part of '../profile_screen.dart';

/// Profil analiz panellerinin (ustalık, en güçlü/en zayıf konu) taradığı
/// kategori kümesi.
///
/// Bu liste `MockZanKurdRepository._allCategories`teki (ve sunucudaki)
/// GERÇEK kategori kümesiyle aynı olmalı. Eskiden burada İKİ AYRI kopyası
/// vardı (`_MasterySection._categories` ve en güçlü/en zayıf hesabının
/// yerel `categories` sabiti) ve ikisi de yalnız sekiz kategoriyi
/// taşıyordu — `Sînema` (2026-07'de eklendi) ve `Teknolojî` (2026-07-26'da
/// dolduruldu) hiçbirinde yoktu. Sonuç: bu iki kategoride ne kadar
/// oynanırsa oynansın, ustalık paneli o kategoriyi hiç göstermiyor, "en
/// güçlü/en zayıf konu" hesabı o kategoriyi hiç adayı olarak görmüyordu
/// (2026-08-14 denetimi). Tek kopya, iki yerden kullanılır — bir kategori
/// eklendiğinde tek satır güncellenir.
const List<String> _kProfileAnalysisCategories = [
  'Ziman',
  'Çand',
  'Dîrok',
  'Edebiyat',
  'Cografya',
  'Muzîk',
  'Siyaset',
  'Paradigma',
  'Sînema',
  'Teknolojî',
  'Cîhan',
];

/// Profil kimliği: avatar (dokununca düzenleme) + ad + oyuncu kodu
/// + vitrin unvanı. Kahraman kart değil — sayfanın kendi zemininde durur;
/// seviye ayrı bir yüzey kartındadır.
///
/// 2026-09-29 Şahnê: eski yeşil degrade kart, süs daireleri, yuvarlak
/// avatar halkası ve degrade kamera rozeti kalktı. Kamera rozeti Kulis
/// tonunda küçük bir karo.
///
/// 2026-09-29 doğallık (K5, K10): kamera rozeti elmastı; elmas yalnız soru
/// ilerlemesi ve ders sayacında kalır, rozet küçük pahlı kare. Oyuncu henüz
/// ad seçmediyse ([hasOwnName] `false`) ad satırı çizilmez: yer tutucu
/// "Oyuncu" başlık gibi duruyor ve oyuncuya adını bilmeyen bir sistem
/// gibi görünüyordu (ana sayfanın selamıyla aynı karar).
class _ProfileHeroCard extends StatelessWidget {
  const _ProfileHeroCard({
    required this.ku,
    required this.displayName,
    required this.hasOwnName,
    required this.avatarIdentity,
    required this.showcaseTitle,
    required this.playerTag,
    required this.rank,
    required this.onEditAvatar,
    required this.level,
    required this.xpInLevel,
    required this.xpNeeded,
    required this.coins,
    required this.onSetName,
    this.streak = 0,
  });

  /// Görünen günlük seri (`StreakStore.effectiveStreak`).
  final int streak;

  /// Kurul 5. tur 2026-10-20 (Opus, Grok): profilin tepesinde kimlik yoktu
  /// (yalnız ZK-kodu). Artık ad (ya da "Adını belirle →"), seviye + XP çubuğu
  /// ve jeton avatarın yanında durur; kod ikincil, küçük.
  final int level;
  final int xpInLevel;
  final int xpNeeded;
  final int? coins;
  final VoidCallback onSetName;

  final bool ku;

  /// Avatarın baş harfi ve renk tohumu için çözülmüş ad (yer tutucu dahil).
  final String displayName;

  /// Oyuncunun kendi seçtiği bir ad var mı; yoksa ad satırı çizilmez.
  final bool hasOwnName;
  final AvatarIdentity avatarIdentity;
  final String? showcaseTitle;

  /// Oyuncunun kendi kodu (ör. `4F7K`).
  ///
  /// Adlar benzersiz değil; arkadaş ararken iki aynı adı ayıran tek şey
  /// bu kod. Oyuncunun onu paylaşabilmesi için kendi profilinde görmesi
  /// gerekiyor. Dokununca panoya kopyalanır (2026-07-28).
  final String? playerTag;
  final int? rank;
  final VoidCallback onEditAvatar;

  /// Kimlik kartının gece-mavi degradesi (VAY_KATMANI B7: #173C52 → #285C70);
  /// iki temada aynı, üstündeki metin beyaz (≥ 4.5:1, bekçi ölçer).
  static const Color cardTop = ProfileIdentityColors.cardTop;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    // 2026-10-29 vay 2B (B7, Astra 5,5/10 "hesap ayarları sayfası gibi"):
    // kimlik artık Duolingo profilindeki gibi bir KİMLİK KARTI — gece-mavi
    // degrade, 80'lik avatar + 6 px seviye halkası, ad, küçük oyuncu kodu
    // ve altta üç sayı (seri · seviye · jeton) + "sonraki seviyeye N XP".
    // Oyuncu kodu ikincil (küçük, soluk beyaz); ad başlıktır.
    //
    // Tur 9b sözleşmesi korunur: blok 16 iç boşluklu TEK kart, avatar üstten
    // hizalı, kamera düğmesi ≥ 44.
    const onCard2 = ProfileIdentityColors.onCard2;
    final xpLeft = math.max(0, xpNeeded - xpInLevel);
    return ProfileIdentitySurface(
      key: const ValueKey('profile-identity-card'),
      child: Padding(
        padding: const EdgeInsets.all(SahneSpace.x4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Ekran okuyucuda etiketsiz bir düğme olarak görünüyordu
                // (2026-07-25 denetimi).
                Semantics(
                  button: true,
                  label: Tr.forKu(K.editAvatar, ku),
                  excludeSemantics: true,
                  onTap: onEditAvatar,
                  child: GestureDetector(
                    key: const ValueKey('profile-avatar-edit'),
                    behavior: HitTestBehavior.opaque,
                    onTap: onEditAvatar,
                    child: SizedBox.square(
                      dimension: 80,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          // Seviye halkası: 6 px Zêr yay, seviye içindeki XP.
                          Positioned.fill(
                            child: CustomPaint(
                              key: const ValueKey('profile-level-ring'),
                              painter: _LevelRingPainter(
                                progress: xpNeeded <= 0
                                    ? 0
                                    : (xpInLevel / xpNeeded).clamp(0.0, 1.0),
                                track: Colors.white.withValues(alpha: 0.22),
                                fill: t.gold,
                                stroke: 6,
                              ),
                            ),
                          ),
                          Center(
                            child: PlayerAvatar(
                              radius: 30,
                              photoUrl: avatarIdentity.photoUrl,
                              iconId: avatarIdentity.iconId,
                              colorHex: avatarIdentity.colorHex,
                              frameId: avatarIdentity.frameId,
                              showcaseTitle: avatarIdentity.showcaseTitle,
                              displayName: displayName,
                              colorSeed: PlayerIdentity.resolveColorSeed(
                                displayName,
                              ),
                            ),
                          ),
                          // Kamera: dokunma alanı 44, görünen yuva 32, simge 20.
                          const PositionedDirectional(
                            end: -SahneSpace.x2 - 2,
                            bottom: -SahneSpace.x2 - 2,
                            child: SizedBox.square(
                              key: ValueKey('profile-camera-button'),
                              dimension: 44,
                              child: Center(
                                child: SizedBox.square(
                                  dimension: 32,
                                  child: DecoratedBox(
                                    decoration: ShapeDecoration(
                                      color: Colors.white,
                                      shape: CircleBorder(
                                        side: BorderSide(
                                          color: cardTop,
                                          width: 2,
                                        ),
                                      ),
                                    ),
                                    child: Icon(
                                      AppIcons.camera,
                                      size: 20,
                                      color: cardTop,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: SahneSpace.x4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Ad varsa ad; yoksa "Oyuncu ZK-4F7K" (kod dokununca
                      // kopyalanır) ve altında kalemli "adını gir".
                      _identityTitle(context, t),
                      if (!hasOwnName)
                        _OnCardLink(
                          key: const ValueKey('profile-set-name-cta'),
                          label: Tr.forKu(
                            K.playerNameHint,
                            ku,
                          ).replaceAll('…', ''),
                          onTap: onSetName,
                        ),
                      if (playerTag != null && hasOwnName)
                        _PlayerTagChip(tag: playerTag!, ku: ku, onDark: true)
                      else if (playerTag == null)
                        Text(
                          Tr.forKu(K.keepProgress, ku),
                          style: SahneType.caption.copyWith(color: onCard2),
                        ),
                      if (showcaseTitle != null) ...[
                        const SizedBox(height: SahneSpace.x1),
                        Text(
                          showcaseTitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: SahneType.captionStrong.copyWith(
                            color: ProfileIdentityColors.gold,
                          ),
                        ),
                      ],
                      // Lig rozeti bayrakla kapalı (bkz. `kWeeklyLeagueEnabled`).
                      if (kWeeklyLeagueEnabled) ...[
                        const SizedBox(height: SahneSpace.x2),
                        Builder(
                          builder: (context) {
                            final tier = LeagueTier.forRank(rank);
                            return SahneBadge(
                              label: tier.label(ku),
                              tone: SahneBadgeTone.gold,
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: SahneSpace.x4),
            // Üç sayı: seri · seviye · jeton (Duolingo profil istatistikleri).
            Builder(
              builder: (context) {
                final cells = <Widget>[
                  _IdentityStat(
                    icon: const Icon(
                      AppIcons.fire,
                      size: 20,
                      color: ProfileIdentityColors.streak,
                    ),
                    value: '$streak',
                    label: Tr.forKu(K.profileStatStreak, ku),
                  ),
                  _IdentityStat(
                    icon: const Icon(
                      AppIcons.star,
                      size: 20,
                      color: ProfileIdentityColors.gold,
                    ),
                    value: '$level',
                    label: Tr.forKu(K.progressLevelLabel, ku),
                  ),
                  if (coins != null)
                    _IdentityStat(
                      key: const ValueKey('profile-coin-pill'),
                      icon: const SahneGlyph(SahneGlyphKind.coin, size: 20),
                      value: groupThousands(coins!),
                      label: Tr.forKu(K.profileStatCoins, ku),
                    ),
                ];
                // Büyük yazıda üç hücre yan yana sığmaz ("Günl/ük"): alt alta.
                final stacked =
                    MediaQuery.textScalerOf(context).scale(16) >= 24;
                if (stacked) {
                  return Column(
                    key: const ValueKey('profile-identity-stats'),
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < cells.length; i++) ...[
                        if (i > 0) const SizedBox(height: SahneSpace.x2),
                        cells[i],
                      ],
                    ],
                  );
                }
                return Row(
                  key: const ValueKey('profile-identity-stats'),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < cells.length; i++) ...[
                      if (i > 0) const SizedBox(width: SahneSpace.x2),
                      Expanded(child: cells[i]),
                    ],
                  ],
                );
              },
            ),
            const SizedBox(height: SahneSpace.x3),
            SahneProgressBar(
              value: xpNeeded > 0 ? xpInLevel / xpNeeded : 0,
              tone: SahneProgressTone.gold,
              height: 8,
              trackColor: Colors.white.withValues(alpha: 0.22),
              edgeColor: Colors.transparent,
              semanticLabel: '${Tr.forKu(K.progressLevelLabel, ku)} $level',
            ),
            const SizedBox(height: SahneSpace.x1),
            Text(
              Tr.forKu(K.profileXpToNext, ku, {'n': groupThousands(xpLeft)}),
              key: const ValueKey('profile-xp-to-next'),
              style: SahneType.caption.copyWith(color: onCard2),
            ),
          ],
        ),
      ),
    );
  }

  /// Kimlik başlığı: ad varsa ad; yoksa "Oyuncu ZK-4F7K" (kod varsa).
  Widget _identityTitle(BuildContext context, SahneTokens t) {
    final label = PlayerIdentity.formatTag(playerTag);
    final text = hasOwnName || label == null
        ? displayName
        : '$displayName $label';
    final title = FittedBox(
      fit: BoxFit.scaleDown,
      alignment: AlignmentDirectional.centerStart,
      child: Text(
        text,
        maxLines: 1,
        style: SahneType.headline.copyWith(color: Colors.white),
      ),
    );
    if (hasOwnName || label == null) return title;
    return Semantics(
      button: true,
      label: Tr.forKu(K.playerTagSemantics, ku, {'tag': label}),
      excludeSemantics: true,
      child: GestureDetector(
        key: const ValueKey('profile-title-tag'),
        behavior: HitTestBehavior.opaque,
        onTap: () => _copyPlayerTag(context, label, ku),
        child: title,
      ),
    );
  }
}

/// Kimlik kartındaki tek sayı hücresi: ikon + kalın değer + küçük etiket,
/// beyaz %12 cam zemin.
class _IdentityStat extends StatelessWidget {
  const _IdentityStat({
    required this.icon,
    required this.value,
    required this.label,
    super.key,
  });

  final Widget icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$value $label',
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          shape: SahneShape.m,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: SahneSpace.x2,
            vertical: SahneSpace.x2,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  icon,
                  const SizedBox(width: SahneSpace.x1),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        value,
                        maxLines: 1,
                        style: SahneType.headline.copyWith(
                          color: Colors.white,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: SahneType.caption.copyWith(
                  color: Colors.white.withValues(alpha: 0.82),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Koyu kart üstünde kalemli metin bağlantısı (≥ 48 dokunma).
class _OnCardLink extends StatelessWidget {
  const _OnCardLink({required this.label, required this.onTap, super.key});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: sahneTapTarget),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(AppIcons.pen, size: 16, color: Colors.white),
              const SizedBox(width: SahneSpace.x2),
              Flexible(
                child: Text(
                  label,
                  style: SahneType.captionStrong.copyWith(
                    color: Colors.white,
                    decoration: TextDecoration.underline,
                    decorationColor: Colors.white.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Oyuncu kodunu panoya kopyalar ve söyler.
Future<void> _copyPlayerTag(BuildContext context, String label, bool ku) async {
  await Clipboard.setData(ClipboardData(text: label));
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(Tr.forKu(K.playerTagCopied, ku)),
        duration: const Duration(seconds: 2),
      ),
    );
}

/// Kendi oyuncu kodun: dokununca panoya kopyalanır.
///
/// Kod paylaşmak içindir — arkadaşın onu arama kutusuna yazınca seni tek
/// ve kesin sonuç olarak bulur. Bu yüzden okunması değil **kopyalanması**
/// asıl iş; dokunma hedefi bütün satırı kapsar (en az 48).
class _PlayerTagChip extends StatelessWidget {
  const _PlayerTagChip({
    required this.tag,
    required this.ku,
    this.onDark = false,
  });

  final String tag;
  final bool ku;

  /// Kimlik kartının koyu degradesinde: soluk beyaz (vay 2B).
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    final label = tag.toUpperCase().startsWith('ZK-') ? tag : 'ZK-$tag';
    return Semantics(
      button: true,
      label: Tr.forKu(K.playerTagSemantics, ku, {'tag': label}),
      excludeSemantics: true,
      child: SahneTappable(
        shape: SahneShape.m,
        color: Colors.transparent,
        onTap: () => _copyPlayerTag(context, label, ku),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: sahneTapTarget,
            minWidth: sahneTapTarget,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // %200 yazı ölçeğinde kod satırı taşırıyordu; kod
              // kısaltılamaz (elle yazılabilmeli) ama küçültülebilir.
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    maxLines: 1,
                    style: SahneType.captionStrong.copyWith(
                      color: onDark
                          ? Colors.white.withValues(alpha: 0.82)
                          : t.tx2,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: SahneSpace.x2),
              Icon(
                AppIcons.copy,
                size: 16,
                color: onDark ? Colors.white.withValues(alpha: 0.82) : t.tx2,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Detaylı analiz içindeki alt başlık (bölüm başlığı değil: kart içi).
class _SubHeading extends StatelessWidget {
  const _SubHeading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Text(
        text,
        style: SahneType.bodyStrong.copyWith(color: SahneTokens.of(context).tx),
      ),
    );
  }
}

/// İstatistik karoları: dar ekranda 2 × 2, genişte 4 sütun. Satırdaki
/// karolar eşit yükseklikte (büyük yazıda uzayan karo komşusunu da uzatır).
class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.tiles});

  final List<Widget> tiles;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth > 600 ? 4 : 2;
        final rows = <Widget>[];
        for (var i = 0; i < tiles.length; i += columns) {
          if (i > 0) rows.add(const SizedBox(height: SahneSpace.x3));
          rows.add(
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var j = i; j < i + columns; j++) ...[
                    if (j > i) const SizedBox(width: SahneSpace.x3),
                    Expanded(
                      child: j < tiles.length
                          ? tiles[j]
                          : const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
            ),
          );
        }
        return Column(children: rows);
      },
    );
  }
}

/// İstatistik karosu: yüzey kartı; rol tonlu ikon karosu, Manşet 22 değer
/// (tablo rakamı, sayarak çıkar), altında açıklama.
class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.role,
    required this.icon,
    this.count,
    this.countPrefix = '',
  });

  final String label;
  final String value;
  final SahneRole role;
  final IconData icon;

  /// Sayısal değer; verildiğinde değer `RollingCount` ile sayarak çıkar.
  /// `value` bu durumda yalnız geri düşüş olarak kalır (ör. "—").
  final int? count;
  final String countPrefix;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    final valueStyle = SahneType.headline.copyWith(
      color: t.tx,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return SahneSurfaceCard(
      padding: const EdgeInsets.all(SahneSpace.x3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          DecoratedBox(
            // 2026-10-20 renk ve canlılık (B): istatistik ikonları mod renginde
            // DOLU (öğrenme Zimrût, yarış Boyax, sosyal Nîl; Zêr ödül).
            decoration: ShapeDecoration(
              color: switch (role) {
                SahneRole.gold => t.gold,
                _ => t.roleFill(role) ?? t.roleTint(role),
              },
              shape: SahneShape.m,
            ),
            child: SizedBox.square(
              dimension: 36,
              child: Icon(
                icon,
                color: switch (role) {
                  SahneRole.gold => t.onGold,
                  SahneRole.neutral => t.roleText(role),
                  _ => SahneVivid.onFill,
                },
                size: 20,
              ),
            ),
          ),
          const SizedBox(height: SahneSpace.x2),
          // Değer tek satırda kalır; dar karoda küçülerek sığar.
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: count != null
                ? RollingCount(
                    value: count!,
                    prefix: countPrefix,
                    maxLines: 1,
                    style: valueStyle,
                  )
                : Text(value, maxLines: 1, style: valueStyle),
          ),
          Text(label, style: SahneType.caption.copyWith(color: t.tx2)),
        ],
      ),
    );
  }
}

// 2026-07-22 canlı UX denetimi: rozet bölümleri birleştirme
// AchievementStore ve BadgeService'den gelen rozetleri tek başlık + tek sayaç
// altında birleştiren bölüm.
class _UnifiedRewardsSection extends StatelessWidget {
  const _UnifiedRewardsSection({
    required this.achievements,
    required this.badgeUnlocked,
    required this.showProgress,
    required this.isKu,
    this.progress = const {},
    this.unlockedOn = const {},
  });

  final List<Achievement> achievements;
  final Set<String> badgeUnlocked;

  /// Başarı/rozet kimliği -> ilerleme (kilitli satırda çubuk ve `x/y`).
  final Map<String, RewardProgress> progress;

  /// Başarı/rozet kimliği -> açılış günü (açılmış satırda tarih).
  final Map<String, DateTime> unlockedOn;

  /// "X/Y" ilerleme çubuğu. İlk turdan önce `false`: "0/13" ve boş çubuk
  /// yeni gelene yalnız eksiğini sayıyordu (2026-09-29 doğallık, K6); kart
  /// o zaman yalnız ilk başarının nasıl açılacağını söyler.
  final bool showProgress;
  final bool isKu;

  void _showAllSheet(BuildContext context) {
    final badgeDefs = BadgeService.badgeDefinitions.entries.toList();
    final achDefs = AchievementStore.definitions;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (ctx, scrollCtrl) {
            final t = SahneTokens.of(ctx);
            return Padding(
              padding: const EdgeInsets.fromLTRB(
                SahneSpace.page,
                SahneSpace.x2,
                SahneSpace.x2,
                SahneSpace.page,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Semantics(
                          header: true,
                          child: Text(
                            Tr.forKu(K.tumBasarilar, isKu),
                            style: SahneType.headline.copyWith(color: t.tx),
                          ),
                        ),
                      ),
                      SahneIconButton(
                        icon: AppIcons.xmark,
                        semanticLabel: Tr.forKu(K.close, isKu),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: SahneSpace.x3),
                  Expanded(
                    child: ListView(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.only(right: SahneSpace.x2),
                      children: [
                        // --- Başarılar bölümü ---
                        if (achDefs.isNotEmpty) ...[
                          _SubHeading(Tr.forKu(K.basarilar, isKu)),
                          const SizedBox(height: SahneSpace.x2),
                          SahneListGroup(
                            children: [
                              for (final def in achDefs)
                                _AchievementRow(
                                  icon: def.icon,
                                  title: def.title(isKu),
                                  description: def.description(isKu),
                                  unlocked: achievements.any(
                                    (a) => a.id == def.id,
                                  ),
                                  progress: progress[def.id],
                                  unlockedOn: unlockedOn[def.id],
                                  isKu: isKu,
                                ),
                            ],
                          ),
                          const SizedBox(height: SahneSpace.x6),
                        ],
                        // --- Rozetler bölümü ---
                        if (badgeDefs.isNotEmpty) ...[
                          _SubHeading(Tr.forKu(K.rozetler, isKu)),
                          const SizedBox(height: SahneSpace.x2),
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  mainAxisSpacing: SahneSpace.x2,
                                  crossAxisSpacing: SahneSpace.x2,
                                  childAspectRatio: 0.76,
                                ),
                            itemCount: badgeDefs.length,
                            itemBuilder: (c, i) {
                              final entry = badgeDefs[i];
                              final data = entry.value;
                              return BadgeWidget(
                                badgeId: entry.key,
                                titleKu: BadgeService.titleFor(entry.key, isKu),
                                titleTr: BadgeService.titleFor(entry.key, isKu),
                                descriptionKu: BadgeService.descFor(
                                  entry.key,
                                  isKu,
                                ),
                                descriptionTr: BadgeService.descFor(
                                  entry.key,
                                  isKu,
                                ),
                                iconName: data['icon'] ?? 'badge',
                                isUnlocked: badgeUnlocked.contains(entry.key),
                                isKu: isKu,
                                progress: progress[entry.key],
                                unlockedOn: unlockedOn[entry.key],
                              );
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    final totalAch = AchievementStore.definitions.length;
    final totalBadge = BadgeService.badgeDefinitions.length;
    final totalUnlocked = achievements.length + badgeUnlocked.length;
    final totalAll = totalAch + totalBadge;
    // Tanım sırasına göre SABİT bir gösterim sırası — `badgeUnlocked`
    // bir `Set` olduğu için kendi sırası garanti değildir.
    final unlockedBadgeIds = BadgeService.badgeDefinitions.keys
        .where(badgeUnlocked.contains)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // "Tümü" bütün başarı ve rozet tanımlarını açar.
        SahneSectionHeader(
          title: Tr.forKu(K.basarilar, isKu),
          actionLabel: Tr.forKu(K.allFilter, isKu),
          actionSemanticLabel: Tr.forKu(K.tumBasarilar, isKu),
          onAction: () => _showAllSheet(context),
        ),
        SahneSurfaceCard(
          key: const ValueKey('profile-rewards-card'),
          onTap: () => _showAllSheet(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // İlerleme ödüldür: Zêr çubuk, sağda "X/Y".
              if (showProgress) ...[
                SahneProgressBar(
                  value: totalAll == 0 ? 0 : totalUnlocked / totalAll,
                  tone: SahneProgressTone.gold,
                  trailing: '$totalUnlocked/$totalAll',
                  semanticLabel: Tr.forKu(K.basarilar, isKu),
                ),
                const SizedBox(height: SahneSpace.x3),
              ],
              if (achievements.isEmpty && badgeUnlocked.isEmpty) ...[
                // Görsellik taraması (2026-10-22, iki denetçi): boş durum
                // tek satır yazıydı. Kazanılacak ilk başarılar kilitli
                // siluet olarak görünür: "yok" değil "hedef" okunur.
                Row(
                  key: const ValueKey('profile-locked-rewards'),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final a in AchievementStore.definitions.take(4))
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: SahneSpace.x2),
                          child: _LockedRewardMark(
                            icon: a.icon,
                            title: a.title(isKu),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: SahneSpace.x3),
                Text(
                  Tr.forKu(K.birYarisTamamlaVe, isKu),
                  style: SahneType.caption.copyWith(color: t.tx2),
                ),
              ] else
                // Önce başarımlar, sonra rozetler; sarar (kaydırma yok).
                Wrap(
                  spacing: SahneSpace.x2,
                  runSpacing: SahneSpace.x2,
                  children: [
                    for (final a in achievements)
                      _RewardChip(icon: a.icon, title: a.title(isKu)),
                    // ESKİ KUSUR (2026-08-14 denetimi): dizin doğrudan
                    // bütün rozet tanımlarına uygulanıyordu; şerit "açılan
                    // rozeti" değil, tanım listesinin ilk N elemanını
                    // gösteriyordu. Kaynak kullanıcının açtığı kümedir.
                    for (final id in unlockedBadgeIds)
                      _RewardChip(
                        icon: AppIcons.star,
                        title: BadgeService.titleFor(id, isKu),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Henüz kazanılmamış başarının kilitli silueti: sönük pahlı karo + ikon,
/// altında ad. Ekran okuyucu adı ve "kilitli" durumunu okur.
class _LockedRewardMark extends StatelessWidget {
  const _LockedRewardMark({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    return Semantics(
      label: title,
      child: ExcludeSemantics(
        child: Column(
          children: [
            Container(
              height: 48,
              alignment: Alignment.center,
              decoration: ShapeDecoration(
                color: t.s2,
                // Kurul 2. tur: siluet iki temada da sönüktü; Zêr kenar ve
                // ikon belirginleşti, ad iki satıra sarar (kesilmesin).
                shape: SahneShape.withSide(
                  SahneShape.s,
                  Color.lerp(t.line, t.goldTx, 0.6)!,
                  width: 1.5,
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(icon, size: 24, color: Color.lerp(t.tx2, t.goldTx, 0.6)),
                  Positioned(
                    right: 6,
                    bottom: 4,
                    child: Icon(AppIcons.lock, size: 11, color: t.tx2),
                  ),
                ],
              ),
            ),
            const SizedBox(height: SahneSpace.x1),
            Text(
              title,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: SahneType.caption.copyWith(color: t.tx2),
            ),
          ],
        ),
      ),
    );
  }
}

/// Avatarın çevresindeki seviye halkası: ince iz + Zêr ilerleme yayı
/// (tepeden saat yönünde).
class _LevelRingPainter extends CustomPainter {
  _LevelRingPainter({
    required this.progress,
    required this.track,
    required this.fill,
    this.stroke = 3.5,
  });

  final double progress;
  final Color track;
  final Color fill;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final arcRect = rect.deflate(stroke / 2);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = track;
    canvas.drawArc(arcRect, 0, math.pi * 2, false, base);
    if (progress <= 0) return;
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = fill;
    canvas.drawArc(arcRect, -math.pi / 2, math.pi * 2 * progress, false, arc);
  }

  @override
  bool shouldRepaint(_LevelRingPainter old) =>
      old.progress != progress || old.track != track || old.fill != fill;
}

/// Kazanılmış başarı / rozet çipi: Zêr tonu, M pah, ikon + ad.
class _RewardChip extends StatelessWidget {
  const _RewardChip({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    return DecoratedBox(
      // Dolu altın (tasarım oylaması 2026-10-22): kazanılmış rozet ödül
      // renginin kendisidir; koyu yazı Zêr bandında okunur.
      decoration: ShapeDecoration(color: t.zerBand, shape: SahneShape.m),
      child: ConstrainedBox(
        // a11y-tap-target: noninteractive — başarı/rozet çipi; salt
        // görsel, dokunma hedefi değil.
        constraints: const BoxConstraints(minHeight: 36),
        child: Padding(
          padding: const EdgeInsetsDirectional.only(
            start: SahneSpace.x2,
            end: SahneSpace.x3,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: t.onZer, size: 16),
              const SizedBox(width: SahneSpace.x2),
              Flexible(
                child: Text(
                  title,
                  style: SahneType.captionStrong.copyWith(color: t.onZer),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Tüm başarılar" sayfasındaki satır: kazanılmışsa Zêr ikon karosu,
/// değilse nötr ve ikincil metin.
class _AchievementRow extends StatelessWidget {
  const _AchievementRow({
    required this.icon,
    required this.title,
    required this.description,
    required this.unlocked,
    required this.isKu,
    this.progress,
    this.unlockedOn,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool unlocked;
  final bool isKu;
  final RewardProgress? progress;
  final DateTime? unlockedOn;

  @override
  Widget build(BuildContext context) {
    // Açılmış: `Kazanıldı: 24.10.2026`. Kilitli: Zêr çubuk + `63/100 soru`.
    // Satır `enabled: unlocked` ile sönük çizilir; ilerleme çubuğu o söndürme
    // içinde de okunur kalır (altın dolgu, metin ayrıca yazılı).
    final Widget? footer = unlocked
        ? RewardUnlockedLabel(unlockedOn: unlockedOn, isKu: isKu)
        : (progress == null
              ? null
              : RewardProgressMeter(progress: progress!, isKu: isKu));
    return SahneListRow.icon(
      icon: icon,
      role: unlocked ? SahneRole.gold : SahneRole.neutral,
      title: title,
      subtitle: description,
      enabled: unlocked,
      footer: footer,
    );
  }
}

class _MasterySection extends StatelessWidget {
  const _MasterySection({required this.store, required this.isKu});

  final MasteryStore store;
  final bool isKu;

  static const _categories = _kProfileAnalysisCategories;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SubHeading(Tr.forKu(K.kategoriUstaligi, isKu)),
        const SizedBox(height: SahneSpace.x3),
        for (final cat in _categories)
          _MasteryRow(category: cat, store: store, isKu: isKu),
      ],
    );
  }
}

/// Ustalık satırı: kategori adı + seviye rozeti (Zêr; başlangıçta nötr),
/// altında Zimrût ilerleme çubuğu ve kanıt metni.
class _MasteryRow extends StatelessWidget {
  const _MasteryRow({
    required this.category,
    required this.store,
    required this.isKu,
  });

  final String category;
  final MasteryStore store;
  final bool isKu;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    final level = store.levelFor(category);
    final count = store.correctCount(category);
    final answered = store.answeredCount(category);
    final accuracy = store.accuracyPercent(category);
    final threshold = store.nextThreshold(category);
    final isMamoste = level == MasteryLevel.mamoste;
    final progress = isMamoste ? 1.0 : (count / threshold).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.only(bottom: SahneSpace.x3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  CategoryNames.localized(category, isKu),
                  style: SahneType.captionStrong.copyWith(color: t.tx),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: SahneSpace.x2),
              Flexible(
                child: SahneBadge(
                  label: level == MasteryLevel.none
                      ? (Tr.forKu(K.baslangic, isKu))
                      : (isKu ? level.titleKu : level.titleTr),
                  tone: level == MasteryLevel.none
                      ? SahneBadgeTone.soon
                      : SahneBadgeTone.gold,
                ),
              ),
            ],
          ),
          const SizedBox(height: SahneSpace.x1),
          SahneProgressBar(
            value: progress,
            semanticLabel: CategoryNames.localized(category, isKu),
          ),
          const SizedBox(height: SahneSpace.x1),
          // Rubik U+2713 taşımıyor; onay işareti metin olarak
          // yazıldığında sistem yazı tipine düşüyordu.
          if (isMamoste && accuracy == null)
            Icon(AppIcons.check, size: 16, color: t.okTx)
          else
            Text(
              accuracy == null
                  ? '$count/$threshold · ${Tr.forKu(K.masteryEvidencePending, isKu, {'correct': '$count'})}'
                  : '$count/$threshold · ${Tr.forKu(K.masteryEvidenceLabel, isKu, {'correct': '$count', 'answered': '$answered', 'accuracy': '$accuracy'})}',
              style: SahneType.caption.copyWith(color: t.tx2),
            ),
        ],
      ),
    );
  }
}

class _PedagogicalAnalyticsSection extends StatefulWidget {
  const _PedagogicalAnalyticsSection({required this.isKu});

  final bool isKu;

  @override
  State<_PedagogicalAnalyticsSection> createState() =>
      _PedagogicalAnalyticsSectionState();
}

class _PedagogicalAnalyticsSectionState
    extends State<_PedagogicalAnalyticsSection> {
  late final Future<List<dynamic>> _dataFuture = Future.wait([
    MistakeStore.load(),
    MasteryStore.load(),
  ]);

  @override
  Widget build(BuildContext context) {
    final isKu = widget.isKu;
    return FutureBuilder<List<dynamic>>(
      future: _dataFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final mistakeStore = snapshot.data![0] as MistakeStore;
        final masteryStore = snapshot.data![1] as MasteryStore;

        final mistakesByCategory = mistakeStore.getMistakesCountByCategory();

        // Find strongest category (highest correctCount in MasteryStore)
        String? strongestCat;
        int maxCorrect = -1;

        // Find weakest category (highest active mistakes in MistakeStore)
        String? weakestCat;
        int maxMistakes = -1;

        const categories = _kProfileAnalysisCategories;

        var masteryCategoriesPlayed = 0;
        var mistakeCategoriesPlayed = 0;

        for (final cat in categories) {
          final corrects = masteryStore.correctCount(cat);
          if (corrects > 0) {
            masteryCategoriesPlayed++;
            if (corrects > maxCorrect) {
              maxCorrect = corrects;
              strongestCat = cat;
            }
          }

          final mistakes = mistakesByCategory[cat] ?? 0;
          if (mistakes > 0) {
            mistakeCategoriesPlayed++;
            if (mistakes > maxMistakes) {
              maxMistakes = mistakes;
              weakestCat = cat;
            }
          }
        }

        // Tek bir kategori oynanmışken o kategori hem "en güçlü" hem de
        // "en zayıf" olarak aynı anda görünüyordu (karşılaştırma yapılacak
        // ikinci bir kategori yoktu) — bkz. 2026-07-04 keşif turu bulgusu.
        // Anlamlı bir karşılaştırma için en az 2 farklı kategoride veri
        // birikene kadar ilgili rozeti gösterme.
        if (masteryCategoriesPlayed < 2) strongestCat = null;
        if (mistakeCategoriesPlayed < 2) weakestCat = null;

        // Build category bar data even if no strongest/weakest
        final categoryBars = <_CategoryBarData>[];
        for (final cat in categories) {
          final corrects = masteryStore.correctCount(cat);
          final mistakes = mistakesByCategory[cat] ?? 0;
          if (corrects > 0 || mistakes > 0) {
            categoryBars.add(_CategoryBarData(cat, corrects, mistakes));
          }
        }
        // Sort by correct count descending
        categoryBars.sort((a, b) => b.correct.compareTo(a.correct));

        final t = SahneTokens.of(context);
        Widget pill(String text, Color bg, Color fg) => DecoratedBox(
          decoration: ShapeDecoration(color: bg, shape: SahneShape.s),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: SahneSpace.x2,
              vertical: SahneSpace.x1,
            ),
            child: Text(
              text,
              style: SahneType.captionStrong.copyWith(color: fg),
            ),
          ),
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SubHeading(Tr.forKu(K.performansAnalizi, isKu)),
            const SizedBox(height: SahneSpace.x3),

            // Kategori performans çubukları
            if (categoryBars.isNotEmpty) ...[
              Text(
                Tr.forKu(K.kategorilereGorePerformans, isKu),
                style: SahneType.caption.copyWith(color: t.tx2),
              ),
              const SizedBox(height: SahneSpace.x2),
              for (final bar in categoryBars) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: SahneSpace.x2),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 80,
                        child: Text(
                          CategoryNames.localized(bar.category, isKu),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: SahneType.caption.copyWith(color: t.tx),
                        ),
                      ),
                      const SizedBox(width: SahneSpace.x2),
                      Expanded(
                        child: CategoryOutcomeBar(
                          key: ValueKey('profile-category-bar-${bar.category}'),
                          correct: bar.correct,
                          mistakes: bar.mistakes,
                        ),
                      ),
                      const SizedBox(width: SahneSpace.x2),
                      SizedBox(
                        width: 40,
                        child: Text(
                          '${bar.correct}',
                          textAlign: TextAlign.right,
                          style: SahneType.captionStrong.copyWith(
                            color: t.okTx,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              // Lejant: durum rengi tek başına değil, sözle birlikte.
              Padding(
                padding: const EdgeInsets.only(top: SahneSpace.x1),
                child: Wrap(
                  spacing: SahneSpace.x4,
                  children: [
                    _LegendDot(color: t.okTx, label: Tr.forKu(K.correct, isKu)),
                    _LegendDot(color: t.errTx, label: Tr.forKu(K.wrong, isKu)),
                  ],
                ),
              ),
              if (strongestCat != null || weakestCat != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: SahneSpace.x3),
                  child: SizedBox(
                    height: 1,
                    width: double.infinity,
                    child: ColoredBox(color: t.line),
                  ),
                ),
            ],

            if (strongestCat != null) ...[
              Text(
                Tr.forKu(K.enGucluOldugunKategori, isKu),
                style: SahneType.caption.copyWith(color: t.tx2),
              ),
              const SizedBox(height: SahneSpace.x1),
              Row(
                children: [
                  pill(
                    CategoryNames.localized(strongestCat, isKu),
                    t.learnTint,
                    t.learnTx,
                  ),
                  const SizedBox(width: SahneSpace.x2),
                  Expanded(
                    child: Text(
                      Tr.forKu(K.pDogruCevap, isKu, {'p0': '$maxCorrect'}),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: SahneType.caption.copyWith(color: t.tx),
                    ),
                  ),
                ],
              ),
            ],
            if (strongestCat != null && weakestCat != null)
              const SizedBox(height: SahneSpace.x3),
            if (weakestCat != null) ...[
              Text(
                Tr.forKu(K.gelistirilmesiGerekenAlan, isKu),
                style: SahneType.caption.copyWith(color: t.tx2),
              ),
              const SizedBox(height: SahneSpace.x1),
              Row(
                children: [
                  pill(
                    CategoryNames.localized(weakestCat, isKu),
                    t.goldTint,
                    t.goldTx,
                  ),
                  const SizedBox(width: SahneSpace.x2),
                  Expanded(
                    child: Text(
                      Tr.forKu(K.pAktifYanlisSoru, isKu, {
                        'p0': '$maxMistakes',
                      }),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: SahneType.caption.copyWith(color: t.tx),
                    ),
                  ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}

// ─── Category Bar Data Model ────────────────────────────────────────────────

class _CategoryBarData {
  const _CategoryBarData(this.category, this.correct, this.mistakes);
  final String category;
  final int correct;
  final int mistakes;
}

// ─── Legend Dot ─────────────────────────────────────────────────────────────

/// Konu başına doğru / yanlış oranı: çubuğun tamamı o konuda verilen
/// cevaplardır, yeşil pay doğru, kırmızı pay yanlış.
///
/// 2026-09-30 simülatör: çubuk eskiden yalnız "doğru + yanlış / en çok
/// cevaplanan konu" uzunluğunda TEK renk (Rast) doluyordu. Her konuda
/// bir cevap varken beş çubuk da tam yeşil çıktı; doğru sayısı 0 olan
/// Wêje ve Erdnîgarî bile yeşil doluydu ve yanlış payı hiç görünmüyordu
/// (lejantta "Rast / Şaş" yazıyordu ama çubuk yalnız Rast'ı çiziyordu).
/// Artık pay renkle ve uzunlukla söylenir. Bekçi:
/// `test/sim_son_2026_09_30_test.dart`.
///
/// Dolum süsüdür: tercih açıkken ilk karede tam boyda durur; yoksa profil
/// analiz paneli ayarı yok sayar. Çubuk bir grafik sütunudur (16 px); iz
/// Ray, yeşil Rast, kırmızı Şaş dolgusu.
@visibleForTesting
class CategoryOutcomeBar extends StatelessWidget {
  const CategoryOutcomeBar({
    required this.correct,
    required this.mistakes,
    super.key,
  });

  final int correct;
  final int mistakes;

  /// Doğru payı (0..1); hiç cevap yoksa 0.
  double get correctShare {
    final total = correct + mistakes;
    return total == 0 ? 0 : correct / total;
  }

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    Widget bar(double grow) => ColoredBox(
      color: t.s3,
      child: SizedBox(
        height: 16,
        width: double.infinity,
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: FractionallySizedBox(
            widthFactor: grow,
            child: Row(
              children: [
                if (correct > 0)
                  Expanded(
                    flex: correct,
                    child: ColoredBox(
                      key: const ValueKey('category-bar-correct'),
                      color: t.okFill,
                      child: const SizedBox(height: 16),
                    ),
                  ),
                if (correct > 0 && mistakes > 0) const SizedBox(width: 2),
                if (mistakes > 0)
                  Expanded(
                    flex: mistakes,
                    child: ColoredBox(
                      key: const ValueKey('category-bar-wrong'),
                      color: t.errFill,
                      child: const SizedBox(height: 16),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    final clipped = ClipPath(
      clipper: const ShapeBorderClipper(shape: SahneShape.s),
      child: ReducedMotionProvider.isReducedIn(context)
          ? bar(1)
          : TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) => bar(value),
            ),
    );
    return clipped;
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox.square(
          dimension: 8,
          child: DecoratedBox(
            decoration: ShapeDecoration(color: color, shape: SahneShape.s),
          ),
        ),
        const SizedBox(width: SahneSpace.x1),
        Text(
          label,
          style: SahneType.caption.copyWith(color: SahneTokens.of(context).tx2),
        ),
      ],
    );
  }
}

/// Misafir hesap yükseltme diyaloğu (e-posta + şifre ya da Google).
///
/// Form anahtarı ve iki alan denetleyicisi bu State'e aittir. Eskiden
/// `_showGuestUpgradeDialog` onları yaratıp `await showDialog` sonrası bir
/// kare beklemeyip atıyordu; kapanış animasyonu onlarca kare sürdüğünden
/// alanlar atılmış denetleyiciyi dinlemeye devam ederdi ("used after being
/// disposed"). Sessizdi: test ortamında route animasyonu çoğu zaman
/// `pumpAndSettle` ile bitmeden kare okunmuyordu.
class _GuestUpgradeDialog extends StatefulWidget {
  const _GuestUpgradeDialog({
    required this.supportsGoogleLinking,
    this.supportsAppleLinking = false,
  });

  final bool supportsGoogleLinking;
  final bool supportsAppleLinking;

  @override
  State<_GuestUpgradeDialog> createState() => _GuestUpgradeDialogState();
}

class _GuestUpgradeDialogState extends State<_GuestUpgradeDialog> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _submitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 40 px diyalog dış payı + 24 px içerik payı, iki yanda.
    final contentWidth =
        (MediaQuery.sizeOf(context).width -
                MediaQuery.paddingOf(context).horizontal -
                128)
            .clamp(1.0, SahneEntryScaffold.columnWidth);
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      scrollable: true,
      title: Text(
        context.t(K.saveAccount),
        style: SahneType.headline.copyWith(color: SahneTokens.of(context).tx),
      ),
      // AlertDialog intrinsic genişlik ister; LayoutBuilder içeren sosyal
      // düğmeler ancak somut bir genişlik altında ölçülebilir.
      content: SizedBox(
        width: contentWidth,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                context.t(K.saveAccountBody),
                style: SahneType.caption.copyWith(
                  color: SahneTokens.of(context).tx2,
                ),
              ),
              const SizedBox(height: SahneSpace.x4),
              if (widget.supportsGoogleLinking ||
                  widget.supportsAppleLinking) ...[
                AuthSocialButtons(
                  linking: true,
                  contentWidth: contentWidth,
                  showGoogle: widget.supportsGoogleLinking,
                  showApple: widget.supportsAppleLinking,
                  appleKey: const ValueKey('guest-upgrade-apple'),
                  onApple: _submitting
                      ? null
                      : () => Navigator.pop(
                          context,
                          _GuestUpgradeAction.appleRequested,
                        ),
                  onGoogle: _submitting
                      ? null
                      : () => Navigator.pop(
                          context,
                          _GuestUpgradeAction.googleRequested,
                        ),
                ),
                AuthEmailDivider(contentWidth: contentWidth),
              ],
              SahneField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                label: context.t(K.email),
                validator: (v) {
                  if (v == null || v.isEmpty || !v.contains('@')) {
                    return context.t(K.emailInvalid);
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              SahneField(
                controller: _passwordController,
                obscureText: true,
                label: context.t(K.password),
                validator: (v) {
                  if (v == null || v.length < 6) {
                    return context.t(K.passwordTooShort);
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        DialogActionPair(
          cancel: OutlinedButton(
            onPressed: _submitting ? null : () => Navigator.pop(context, null),
            child: Text(context.t(K.cancel)),
          ),
          confirm: FilledButton(
            onPressed: _submitting
                ? null
                : () async {
                    if (!(_formKey.currentState?.validate() ?? false)) {
                      return;
                    }
                    setState(() => _submitting = true);
                    try {
                      final auth = context.read<AuthProvider>();
                      final navigator = Navigator.of(context);
                      final success = await auth.upgradeGuestAccount(
                        email: _emailController.text.trim(),
                        password: _passwordController.text,
                      );
                      if (!mounted) return;
                      navigator.pop(
                        !success
                            ? _GuestUpgradeAction.emailFailure
                            : auth.needsEmailConfirmation
                            ? _GuestUpgradeAction.emailPendingConfirmation
                            : _GuestUpgradeAction.emailSuccess,
                      );
                    } finally {
                      if (mounted) setState(() => _submitting = false);
                    }
                  },
            child: _submitting
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: SahneTokens.of(context).tx3,
                    ),
                  )
                : Text(context.t(K.save)),
          ),
        ),
      ],
    );
  }
}
