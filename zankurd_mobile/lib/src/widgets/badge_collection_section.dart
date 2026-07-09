import 'package:flutter/material.dart';

import '../data/badge_service.dart';
import '../l10n/lang.dart';
import '../theme/app_theme.dart';
import '../widgets/badge_widget.dart';

/// Profil ekranında rozet koleksiyonunu gösteren bölüm.
class BadgeCollectionSection extends StatefulWidget {
  const BadgeCollectionSection({super.key});

  @override
  State<BadgeCollectionSection> createState() => _BadgeCollectionSectionState();
}

class _BadgeCollectionSectionState extends State<BadgeCollectionSection> {
  Set<String> _unlockedBadges = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final service = await BadgeService.load();
    if (mounted) {
      setState(() {
        _unlockedBadges = service.unlockedBadges;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ku = context.isKu;

    if (_loading) {
      return const SizedBox(
        height: 100,
        child: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppTheme.primaryGradientStart,
          ),
        ),
      );
    }

    final badges = BadgeService.badgeDefinitions.entries.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.workspace_premium_outlined, color: AppTheme.gold),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                ku ? 'Koleksiyona Rozetên' : 'Rozet Koleksiyonu',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppTheme.textPrimaryColor(context),
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.gold.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${_unlockedBadges.length}/${badges.length}',
                style: const TextStyle(
                  color: AppTheme.gold,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () => _showAllBadgesSheet(context, badges, ku),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                ku ? 'Hemû' : 'Tümünü Gör',
                style: const TextStyle(
                  color: AppTheme.primaryGradientStart,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 110,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: badges.length,
            itemBuilder: (context, index) {
              final entry = badges[index];
              final data = entry.value;
              return Container(
                width: 86,
                margin: EdgeInsets.only(
                  right: index == badges.length - 1 ? 0 : 8,
                ),
                child: BadgeWidget(
                  badgeId: entry.key,
                  titleKu: data['titleKu'] ?? '',
                  titleTr: data['titleTr'] ?? '',
                  descriptionKu: data['descKu'] ?? '',
                  descriptionTr: data['descTr'] ?? '',
                  iconName: data['icon'] ?? 'badge',
                  isUnlocked: _unlockedBadges.contains(entry.key),
                  isKu: ku,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showAllBadgesSheet(
    BuildContext context,
    List<MapEntry<String, Map<String, String>>> badges,
    bool ku,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor(context),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: AppTheme.borderColor(context).withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.workspace_premium_outlined, color: AppTheme.gold),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          ku ? 'Koleksiyona Rozetên' : 'Rozet Koleksiyonu',
                          style: TextStyle(
                            color: AppTheme.textPrimaryColor(context),
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: GridView.builder(
                      controller: scrollController,
                      itemCount: badges.length,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: 0.76,
                      ),
                      itemBuilder: (context, index) {
                        final entry = badges[index];
                        final data = entry.value;
                        return BadgeWidget(
                          badgeId: entry.key,
                          titleKu: data['titleKu'] ?? '',
                          titleTr: data['titleTr'] ?? '',
                          descriptionKu: data['descKu'] ?? '',
                          descriptionTr: data['descTr'] ?? '',
                          iconName: data['icon'] ?? 'badge',
                          isUnlocked: _unlockedBadges.contains(entry.key),
                          isKu: ku,
                        );
                      },
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
}
