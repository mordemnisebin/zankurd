part of '../profile_screen.dart';

class _ProfileHeroCard extends StatelessWidget {
  const _ProfileHeroCard({
    required this.ku,
    required this.displayName,
    required this.avatarIdentity,
    required this.showcaseTitle,
    required this.level,
    required this.xpInLevel,
    required this.xpNeeded,
    required this.rank,
    required this.levelProgress,
    required this.onEditAvatar,
  });

  final bool ku;
  final String displayName;
  final AvatarIdentity avatarIdentity;
  final String? showcaseTitle;
  final int level;
  final int xpInLevel;
  final int xpNeeded;
  final int? rank;
  final double levelProgress;
  final VoidCallback onEditAvatar;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF163D2D), Color(0xFF1E4B38), Color(0xFF275742)],
          ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
          boxShadow: [
            BoxShadow(
              color: AppTheme.culturalBrandBg.withValues(alpha: 0.32),
              blurRadius: 28,
              offset: const Offset(0, 14),
              spreadRadius: -10,
            ),
          ],
        ),
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Stack(
          children: [
            Positioned(
              right: -24,
              top: -28,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.06),
                ),
              ),
            ),
            Positioned(
              left: -18,
              bottom: -36,
              child: Container(
                width: 112,
                height: 112,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.brand.withValues(alpha: 0.10),
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    InkWell(
                      key: const ValueKey('profile-avatar-edit'),
                      customBorder: const CircleBorder(),
                      onTap: onEditAvatar,
                      child: Stack(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.88),
                                width: 2.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.16),
                                  blurRadius: 14,
                                  offset: const Offset(0, 6),
                                  spreadRadius: -4,
                                ),
                              ],
                            ),
                            child: PlayerAvatar(
                              radius: 34,
                              photoUrl: avatarIdentity.photoUrl,
                              iconId: avatarIdentity.iconId,
                              colorHex: avatarIdentity.colorHex,
                              frameId: avatarIdentity.frameId,
                              displayName: displayName,
                            ),
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                gradient: AppTheme.accentGradient,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.92),
                                  width: 2,
                                ),
                              ),
                              child: const Icon(
                                AppIcons.camera,
                                size: 12,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              displayName,
                              maxLines: 1,
                              style: AppTypography.heading2.copyWith(
                                color: Colors.white,
                                fontSize: 24,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            ku ? 'Rêça xwe berdewam bike' : 'İlerlemeni sürdür',
                            style: AppTypography.caption.copyWith(
                              color: Colors.white.withValues(alpha: 0.74),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (showcaseTitle != null)
                            Container(
                              margin: const EdgeInsets.only(top: AppSpacing.xs),
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.sm,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(
                                  AppRadius.pill,
                                ),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.16),
                                ),
                              ),
                              child: Text(
                                showcaseTitle!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.caption.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            )
                          else
                            const SizedBox.shrink(),

                          const SizedBox(height: 8),
                          Builder(
                            builder: (context) {
                              final tier = LeagueTier.forRank(rank);
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.heroScrim(),
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.badge,
                                  ),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.18),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      tier.icon,
                                      color: Colors.white,
                                      size: 14,
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      tier.label(ku),
                                      style: AppTypography.caption.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Divider(color: Colors.white.withValues(alpha: 0.18), height: 1),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    const Icon(AppIcons.medal, color: AppTheme.gold, size: 22),
                    const SizedBox(width: AppSpacing.xxs),
                    Flexible(
                      child: Text(
                        ku ? 'Ast $level' : 'Seviye $level',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodyLarge.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Flexible(
                      child: Text(
                        '$xpInLevel / $xpNeeded XP',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                        style: AppTypography.caption.copyWith(
                          color: Colors.white.withValues(alpha: 0.74),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                  child: Stack(
                    children: [
                      Container(
                        height: 9,
                        color: Colors.white.withValues(alpha: 0.18),
                      ),
                      FractionallySizedBox(
                        widthFactor: levelProgress.clamp(0.0, 1.0),
                        child: Container(
                          height: 9,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFFC85C), Color(0xFFF29D31)],
                            ),
                            borderRadius: BorderRadius.circular(AppRadius.xs),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: AppTheme.statCard(context, color),
      // Grid hücresi dar/kısa olduğunda (childAspectRatio) içerik taşıyordu.
      // FittedBox(scaleDown) içeriği hücreye sığdırır; normal boyutta görünüm
      // değişmez (scaleDown yalnız küçültür, büyütmez).
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.iconTileBg(context, color),
                borderRadius: BorderRadius.circular(AppRadius.xs),
              ),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.bodyLarge.copyWith(
                color: AppColors.toneOnSurface(context, color),
                fontSize: 17,
              ),
            ),
            Text(
              label,
              maxLines: 1,
              style: AppTypography.caption.copyWith(
                color: AppTheme.textMutedColor(context),
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 2026-07-22 canlı UX denetimi: rozet bölümleri birleştirme
// AchievementStore ve BadgeService'den gelen rozetleri tek başlık + tek sayaç
// altında birleştiren widget.
class _UnifiedRewardsSection extends StatelessWidget {
  const _UnifiedRewardsSection({
    required this.achievements,
    required this.badgeUnlocked,
    required this.isKu,
  });

  final List<Achievement> achievements;
  final Set<String> badgeUnlocked;
  final bool isKu;

  void _showAllSheet(BuildContext context) {
    final badgeDefs = BadgeService.badgeDefinitions.entries.toList();
    final achDefs = AchievementStore.definitions;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (ctx, scrollCtrl) {
            return Container(
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor(context),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: AppTheme.borderColor(
                        context,
                      ).withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(AppRadius.badge),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(AppIcons.medal, color: AppTheme.gold),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isKu ? 'Hemû Destkeftî' : 'Tüm Başarılar',
                          style: AppTypography.heading2.copyWith(
                            color: AppTheme.textPrimaryColor(context),
                            fontSize: 20,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        tooltip: isKu ? 'Bigire' : 'Kapat',
                        icon: const Icon(AppIcons.xmark),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView(
                      controller: scrollCtrl,
                      children: [
                        // --- Başarılar bölümü ---
                        if (achDefs.isNotEmpty) ...[
                          Text(
                            isKu ? 'Destkeftî' : 'Başarılar',
                            style: AppTypography.bodyLarge.copyWith(
                              color: AppTheme.textPrimaryColor(context),
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 8),
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 10,
                                  mainAxisSpacing: 10,
                                  childAspectRatio: 2.8,
                                ),
                            itemCount: achDefs.length,
                            itemBuilder: (c, i) {
                              final def = achDefs[i];
                              final unlocked = achievements.any(
                                (a) => a.id == def.id,
                              );
                              final color = unlocked
                                  ? AppTheme.gold
                                  : AppTheme.textMutedColor(context);
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: unlocked
                                      ? AppTheme.gold.withValues(alpha: 0.08)
                                      : AppTheme.surfaceHiColor(
                                          context,
                                        ).withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(AppRadius.sm),
                                  border: Border.all(
                                    color: unlocked
                                        ? AppTheme.gold.withValues(alpha: 0.25)
                                        : AppTheme.borderColor(context),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(def.icon, color: color, size: 20),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            def.title(isKu),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: AppTypography.caption.copyWith(
                                              color: unlocked
                                                  ? AppTheme.textPrimaryColor(
                                                      context,
                                                    )
                                                  : AppTheme.textMutedColor(
                                                      context,
                                                    ),
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            def.description(isKu),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: AppTypography.caption
                                                .copyWith(
                                                  color:
                                                      AppTheme.textMutedColor(
                                                        context,
                                                      ),
                                                  fontSize: 10,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 16),
                        ],
                        // --- Rozetler bölümü ---
                        if (badgeDefs.isNotEmpty) ...[
                          Text(
                            isKu ? 'Rozet' : 'Rozetler',
                            style: AppTypography.bodyLarge.copyWith(
                              color: AppTheme.textPrimaryColor(context),
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 8),
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  mainAxisSpacing: 10,
                                  crossAxisSpacing: 10,
                                  childAspectRatio: 0.76,
                                ),
                            itemCount: badgeDefs.length,
                            itemBuilder: (c, i) {
                              final entry = badgeDefs[i];
                              final data = entry.value;
                              return BadgeWidget(
                                badgeId: entry.key,
                                titleKu: data['titleKu'] ?? '',
                                titleTr: data['titleTr'] ?? '',
                                descriptionKu: data['descKu'] ?? '',
                                descriptionTr: data['descTr'] ?? '',
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
    final totalAch = AchievementStore.definitions.length;
    final totalBadge = BadgeService.badgeDefinitions.length;
    final totalUnlocked = achievements.length + badgeUnlocked.length;
    final totalAll = totalAch + totalBadge;

    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(AppIcons.medal, color: AppTheme.gold),
              const SizedBox(width: 8),
              Text(
                isKu ? 'Destkeftî' : 'Başarılar',
                style: AppTypography.bodyLarge.copyWith(
                  color: AppTheme.textPrimaryColor(context),
                  fontWeight: FontWeight.w700,
                  fontSize: 17,
                ),
              ),
              const Spacer(),
              // 2026-07-22 canlı UX denetimi: CTA erişilebilirlik düzeltmesi
              TextButton(
                onPressed: () => _showAllSheet(context),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(44, 44),
                ),
                child: ExcludeSemantics(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$totalUnlocked/$totalAll',
                        style: TextStyle(
                          color: AppTheme.textMutedColor(context),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        AppIcons.chevronRight,
                        color: AppTheme.textMutedColor(context),
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Yatay kaydırma: önce başarımlar, sonra rozetler
          if (achievements.isEmpty && badgeUnlocked.isEmpty)
            Text(
              isKu
                  ? 'Pêşbirkekê biqedîne û destkeftiya yekem veke.'
                  : 'Bir yarış tamamla ve ilk başarımı aç.',
              style: const TextStyle(color: AppTheme.textMuted),
            )
          else
            SizedBox(
              height: 38,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: achievements.length + badgeUnlocked.length,
                itemBuilder: (context, index) {
                  if (index < achievements.length) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _AchievementChip(
                        achievement: achievements[index],
                        isKu: isKu,
                      ),
                    );
                  }
                  // Badge chip
                  final badgeIndex = index - achievements.length;
                  final badgeEntry = BadgeService.badgeDefinitions.entries
                      .elementAt(badgeIndex);
                  final data = badgeEntry.value;
                  final title = isKu
                      ? (data['titleKu'] ?? '')
                      : (data['titleTr'] ?? '');
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        border: Border.all(
                          color: AppTheme.accent.withValues(alpha: 0.24),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            AppIcons.star,
                            color: AppTheme.accent,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            title,
                            style: AppTypography.caption.copyWith(
                              color: AppTheme.textPrimaryColor(context),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _MasterySection extends StatelessWidget {
  const _MasterySection({required this.store, required this.isKu});

  final MasteryStore store;
  final bool isKu;

  static const _categories = [
    'Ziman',
    'Çand',
    'Dîrok',
    'Edebiyat',
    'Cografya',
    'Muzîk',
    'Siyaset',
    'Paradigma',
  ];

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(AppIcons.medal, color: AppTheme.violet),
              const SizedBox(width: 8),
              // Dar (iki sütunlu masaüstü) panelde başlık taşmasın.
              Expanded(
                child: Text(
                  isKu ? 'Ustalîya Kategoriyê' : 'Kategori Ustalığı',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodyLarge.copyWith(
                    color: AppTheme.textPrimaryColor(context),
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          for (final cat in _categories)
            _MasteryRow(category: cat, store: store, isKu: isKu),
        ],
      ),
    );
  }
}

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
    final level = store.levelFor(category);
    final count = store.correctCount(category);
    final threshold = store.nextThreshold(category);
    final isMamoste = level == MasteryLevel.mamoste;
    final progress = isMamoste ? 1.0 : (count / threshold).clamp(0.0, 1.0);
    final badgeColor = level == MasteryLevel.none
        ? AppTheme.textMuted
        : level.badgeColor;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(
            width: 76,
            child: Text(
              CategoryNames.localized(category, isKu),
              style: AppTypography.bodyMedium.copyWith(
                color: AppTheme.textPrimaryColor(context),
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          // Rozet çipi dar panelde satırı taşırmasın diye esner.
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: badgeColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
              ),
              child: Text(
                level == MasteryLevel.none
                    ? (isKu ? 'Destpêkirin' : 'Başlangıç')
                    : (isKu ? level.titleKu : level.titleTr),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.caption.copyWith(
                  color: badgeColor,
                  fontSize: 10,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: AppTheme.borderColor(context),
                    valueColor: AlwaysStoppedAnimation<Color>(badgeColor),
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isMamoste ? '✓' : '$count/$threshold',
                  style: AppTypography.caption.copyWith(
                    color: AppTheme.textMutedColor(context),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AchievementChip extends StatelessWidget {
  const _AchievementChip({required this.achievement, required this.isKu});

  final Achievement achievement;
  final bool isKu;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.gold.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppTheme.gold.withValues(alpha: 0.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(achievement.icon, color: AppTheme.gold, size: 18),
          const SizedBox(width: 6),
          Text(
            achievement.title(isKu),
            style: AppTypography.caption.copyWith(
              color: AppTheme.textPrimaryColor(context),
              fontWeight: FontWeight.w800,
            ),
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

        const categories = [
          'Ziman',
          'Çand',
          'Dîrok',
          'Edebiyat',
          'Cografya',
          'Muzîk',
          'Siyaset',
          'Paradigma',
        ];

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
        final maxBar = categoryBars.isEmpty
            ? 1
            : categoryBars
                  .map((e) => e.correct + e.mistakes)
                  .reduce((a, b) => a > b ? a : b);

        return AppPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(AppIcons.chartLine, color: AppTheme.accent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isKu ? 'Analîza Performansê' : 'Performans Analizi',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodyLarge.copyWith(
                        color: AppTheme.textPrimaryColor(context),
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // 📊 Category performance bars
              if (categoryBars.isNotEmpty) ...[
                Text(
                  isKu
                      ? 'Performansa li gor kategoriyan'
                      : 'Kategorilere göre performans',
                  style: AppTypography.caption.copyWith(
                    color: AppTheme.textMutedColor(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                for (final bar in categoryBars) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 72,
                          child: Text(
                            isKu
                                ? CategoryNames.localized(bar.category, true)
                                : CategoryNames.localized(bar.category, false),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.caption.copyWith(
                              color: AppTheme.textPrimaryColor(context),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: TweenAnimationBuilder<double>(
                              tween: Tween(
                                begin: 0,
                                end: (bar.correct + bar.mistakes) / maxBar,
                              ),
                              duration: const Duration(milliseconds: 700),
                              curve: Curves.easeOutCubic,
                              builder: (context, value, _) =>
                                  LinearProgressIndicator(
                                    value: value,
                                    minHeight: 16,
                                    backgroundColor: AppTheme.surfaceColor(
                                      context,
                                    ),
                                    color: AppTheme.correct,
                                  ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 40,
                          child: Text(
                            '${bar.correct}',
                            textAlign: TextAlign.right,
                            style: AppTypography.caption.copyWith(
                              color: AppTheme.correct,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                // Legend
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      _LegendDot(
                        color: AppTheme.correct,
                        label: isKu ? 'Rast' : 'Doğru',
                      ),
                      const SizedBox(width: 16),
                      _LegendDot(
                        color: AppTheme.wrong,
                        label: isKu ? 'Şaş' : 'Yanlış',
                      ),
                    ],
                  ),
                ),
                if (strongestCat != null || weakestCat != null)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Divider(),
                  ),
              ],

              if (strongestCat != null) ...[
                Text(
                  isKu
                      ? 'Kategoriya te ya herî bihêz:'
                      : 'En güçlü olduğun kategori:',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppTheme.textMutedColor(context),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.correct.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: AppTheme.correct.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Text(
                        strongestCat,
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppTheme.correct,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isKu
                            ? '$maxCorrect bersivên rast'
                            : '$maxCorrect doğru cevap',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppTheme.textPrimaryColor(context),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              if (strongestCat != null && weakestCat != null)
                const SizedBox(height: 14),
              if (weakestCat != null) ...[
                Text(
                  isKu
                      ? 'Kategoriya ku divê tu pêş bixî:'
                      : 'Geliştirilmesi gereken alan:',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppTheme.textMutedColor(context),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.brand.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: AppTheme.brand.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Text(
                        weakestCat,
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.readableAccent(
                            context,
                            AppTheme.brand,
                          ),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isKu
                            ? '$maxMistakes pirsên şaş ên çalak'
                            : '$maxMistakes aktif yanlış soru',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppTheme.textPrimaryColor(context),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
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

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: AppTypography.caption.copyWith(
            color: AppTheme.textMutedColor(context),
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
