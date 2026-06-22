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
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    final badges = BadgeService.badgeDefinitions.entries.toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        int crossCount = 3;
        if (constraints.maxWidth > 900) {
          crossCount = 6;
        } else if (constraints.maxWidth > 600) {
          crossCount = 5;
        }

        double aspectRatio = 0.85;
        if (constraints.maxWidth < 450) {
          aspectRatio = 0.72;
        }

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
                      fontWeight: FontWeight.w900,
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
              ],
            ),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossCount,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: aspectRatio,
              ),
              itemCount: badges.length,
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
          ],
        );
      },
    );
  }
}
