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
  });

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

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    return Row(
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
                children: [
                  Center(
                    child: PlayerAvatar(
                      radius: 36,
                      photoUrl: avatarIdentity.photoUrl,
                      iconId: avatarIdentity.iconId,
                      colorHex: avatarIdentity.colorHex,
                      frameId: avatarIdentity.frameId,
                      displayName: displayName,
                      colorSeed: PlayerIdentity.resolveColorSeed(displayName),
                    ),
                  ),
                  PositionedDirectional(
                    end: 0,
                    bottom: 0,
                    child: SizedBox.square(
                      dimension: 28,
                      child: DecoratedBox(
                        decoration: ShapeDecoration(
                          color: t.s2,
                          shape: SahneShape.withSide(
                            SahneShape.forSize(28),
                            t.bg,
                            width: SahneRing.r2,
                          ),
                        ),
                        child: Icon(AppIcons.camera, size: 12, color: t.tx),
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
              if (hasOwnName)
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    displayName,
                    maxLines: 1,
                    style: SahneType.headline.copyWith(color: t.tx),
                  ),
                ),
              if (playerTag != null)
                _PlayerTagChip(tag: playerTag!, ku: ku)
              else
                Text(
                  Tr.forKu(K.keepProgress, ku),
                  style: SahneType.caption.copyWith(color: t.tx2),
                ),
              if (showcaseTitle != null) ...[
                const SizedBox(height: SahneSpace.x1),
                Text(
                  showcaseTitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SahneType.captionStrong.copyWith(color: t.goldTx),
                ),
              ],
              // Lig rozeti bayrakla kapalı: az oyuncuyla herkes "Bronz
              // Lig"de (bkz. `kWeeklyLeagueEnabled`).
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
    );
  }
}

/// Kendi oyuncu kodun: dokununca panoya kopyalanır.
///
/// Kod paylaşmak içindir — arkadaşın onu arama kutusuna yazınca seni tek
/// ve kesin sonuç olarak bulur. Bu yüzden okunması değil **kopyalanması**
/// asıl iş; dokunma hedefi bütün satırı kapsar (en az 48).
class _PlayerTagChip extends StatelessWidget {
  const _PlayerTagChip({required this.tag, required this.ku});

  final String tag;
  final bool ku;

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
        onTap: () async {
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
        },
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
                      color: t.tx2,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: SahneSpace.x2),
              Icon(AppIcons.copy, size: 16, color: t.tx2),
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
            decoration: ShapeDecoration(
              color: t.roleTint(role),
              shape: SahneShape.m,
            ),
            child: SizedBox.square(
              dimension: 36,
              child: Icon(icon, color: t.roleText(role), size: 20),
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
  });

  final List<Achievement> achievements;
  final Set<String> badgeUnlocked;

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
              if (achievements.isEmpty && badgeUnlocked.isEmpty)
                Text(
                  Tr.forKu(K.birYarisTamamlaVe, isKu),
                  style: SahneType.caption.copyWith(color: t.tx2),
                )
              else
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

/// Kazanılmış başarı / rozet çipi: Zêr tonu, M pah, ikon + ad.
class _RewardChip extends StatelessWidget {
  const _RewardChip({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    return DecoratedBox(
      decoration: ShapeDecoration(color: t.goldTint, shape: SahneShape.m),
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
              Icon(icon, color: t.goldTx, size: 16),
              const SizedBox(width: SahneSpace.x2),
              Flexible(
                child: Text(
                  title,
                  style: SahneType.captionStrong.copyWith(color: t.tx),
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
  });

  final IconData icon;
  final String title;
  final String description;
  final bool unlocked;

  @override
  Widget build(BuildContext context) {
    return SahneListRow.icon(
      icon: icon,
      role: unlocked ? SahneRole.gold : SahneRole.neutral,
      title: title,
      subtitle: description,
      enabled: unlocked,
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
