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
  final double levelProgress;
  final VoidCallback onEditAvatar;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: Container(
        decoration: BoxDecoration(
          // Kategorî/mockup-4 dili: koyu düz yüzey + altın sınır — büyük
          // gradyan hero kalıntısı yerine.
          color: AppTheme.surfaceColor(context),
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: AppTheme.gold.withValues(alpha: 0.35)),
        ),
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Stack(
          children: [
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
                          // Mockup 10: altın halkalı avatar.
                          Container(
                            padding: const EdgeInsets.all(2.5),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppTheme.gold,
                                width: 2.5,
                              ),
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
                          // Mockup 10: yeşil kamera rozeti.
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: AppTheme.correct,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppTheme.surfaceColor(context),
                                  width: 2,
                                ),
                              ),
                              child: const Icon(
                                Icons.photo_camera,
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
                          Text(
                            displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.heading2.copyWith(
                              color: AppTheme.textPrimaryColor(context),
                            ),
                          ),
                          if (showcaseTitle != null)
                            Container(
                              margin: const EdgeInsets.only(
                                top: AppSpacing.xxs,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.xs,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.gold.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(
                                  AppRadius.pill,
                                ),
                              ),
                              child: Text(
                                showcaseTitle!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.caption.copyWith(
                                  color: AppTheme.gold,
                                ),
                              ),
                            )
                          else
                            const SizedBox.shrink(),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Divider(color: AppTheme.borderColor(context), height: 1),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    const Icon(
                      Icons.military_tech_rounded,
                      color: AppTheme.gold,
                      size: 22,
                    ),
                    const SizedBox(width: AppSpacing.xxs),
                    Flexible(
                      child: Text(
                        ku ? 'Ast $level' : 'Seviye $level',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodyLarge.copyWith(
                          color: AppTheme.textPrimaryColor(context),
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
                          color: AppTheme.textSubColor(context),
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
                        height: 8,
                        color: AppTheme.borderColor(context),
                      ),
                      FractionallySizedBox(
                        widthFactor: levelProgress.clamp(0.0, 1.0),
                        child: Container(
                          height: 8,
                          decoration: BoxDecoration(
                            gradient: AppTheme.goldGradient,
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
            overflow: TextOverflow.ellipsis,
            style: AppTypography.caption.copyWith(
              color: AppTheme.textMutedColor(context),
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _AchievementShowcase extends StatelessWidget {
  const _AchievementShowcase({required this.achievements, required this.isKu});

  final List<Achievement> achievements;
  final bool isKu;

  void _showAllAchievementsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceColor(context),
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        side: BorderSide(color: AppTheme.borderColor(context)),
      ),
      builder: (sheetContext) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor(context),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isKu ? 'Hemû Rozet' : 'Tüm Rozetler',
                    style: AppTypography.heading2.copyWith(
                      color: AppTheme.textPrimaryColor(context),
                      fontSize: 20,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: isKu ? 'Bigire' : 'Kapat',
                    onPressed: () => Navigator.pop(sheetContext),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 2.8,
                  ),
                  itemCount: AchievementStore.definitions.length,
                  itemBuilder: (context, index) {
                    final definition = AchievementStore.definitions[index];
                    final isUnlocked = achievements.any(
                      (a) => a.id == definition.id,
                    );
                    final color = isUnlocked
                        ? AppTheme.gold
                        : AppTheme.textMutedColor(context);
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isUnlocked
                            ? AppTheme.gold.withValues(alpha: 0.08)
                            : AppTheme.surfaceHiColor(
                                context,
                              ).withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isUnlocked
                              ? AppTheme.gold.withValues(alpha: 0.25)
                              : AppTheme.borderColor(context),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(definition.icon, color: color, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  definition.title(isKu),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.caption.copyWith(
                                    color: isUnlocked
                                        ? AppTheme.textPrimaryColor(context)
                                        : AppTheme.textMutedColor(context),
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  definition.description(isKu),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.caption.copyWith(
                                    color: AppTheme.textMutedColor(context),
                                    fontSize: 9,
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
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Henüz rozet kazanılmamışsa şerit yerine tek satırlık kompakt kart.
    if (achievements.isEmpty) {
      return AppPanel(
        padding: EdgeInsets.zero,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.card),
          onTap: () => _showAllAchievementsSheet(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.workspace_premium_outlined,
                  color: AppTheme.gold,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isKu
                        ? 'Rozet 0/${AchievementStore.definitions.length} — pêşbirkekê biqedîne û rozeta yekem veke'
                        : 'Rozet 0/${AchievementStore.definitions.length} — bir yarış tamamla, ilk rozeti aç',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppTheme.textMutedColor(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppTheme.textMutedColor(context),
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      );
    }
    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.workspace_premium_outlined, color: AppTheme.gold),
              const SizedBox(width: 8),
              Text(
                isKu ? 'Rozet' : 'Rozetler',
                style: AppTypography.bodyLarge.copyWith(
                  color: AppTheme.textPrimaryColor(context),
                  fontWeight: FontWeight.w700,
                  fontSize: 17,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => _showAllAchievementsSheet(context),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(44, 44),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${achievements.length}/${AchievementStore.definitions.length}',
                      style: TextStyle(
                        color: AppTheme.textMutedColor(context),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: AppTheme.textMutedColor(context),
                      size: 16,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (achievements.isEmpty)
            Text(
              isKu
                  ? 'Pêşbirkekê biqedîne û rozeta yekem veke.'
                  : 'Bir yarış tamamla ve ilk rozetini aç.',
              style: TextStyle(color: AppTheme.textMuted),
            )
          else
            SizedBox(
              height: 38,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: achievements.length,
                itemBuilder: (context, index) {
                  final achievement = achievements[index];
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _AchievementChip(
                      achievement: achievement,
                      isKu: isKu,
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
              Icon(Icons.workspace_premium_outlined, color: AppTheme.violet),
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
                    fontSize: 9,
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
        borderRadius: BorderRadius.circular(12),
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

class _PedagogicalAnalyticsSection extends StatelessWidget {
  const _PedagogicalAnalyticsSection({required this.isKu});

  final bool isKu;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: Future.wait([MistakeStore.load(), MasteryStore.load()]),
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
                  Icon(Icons.analytics_outlined, color: AppTheme.accent),
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
                        color: Colors.orange.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: Colors.orange.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Text(
                        weakestCat,
                        style: AppTypography.bodyMedium.copyWith(
                          color: Colors.orange,
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
