import 'package:flutter/material.dart';

import '../../l10n/lang.dart';
import '../../theme/app_theme.dart';
import '../../widgets/kilim_pattern_painter.dart';

/// Day-of-week themed contest card showing today's category.
///
/// Monday = Ziman, Tuesday = Çand, Wednesday = Dîrok, Thursday = Edebiyat,
/// Friday = Cografya, Saturday = Muzîk, Sunday = Karma.
///
/// Displays a themed icon, category name, tap-to-open prompt,
/// and a countdown to the next theme.
class DailyThemeCard extends StatelessWidget {
  const DailyThemeCard({
    required this.isKu,
    this.onTap,
    this.dayOverride,
    super.key,
  });

  final bool isKu;
  final VoidCallback? onTap;

  /// Test override: force a specific weekday (1=Mon, 7=Sun).
  final int? dayOverride;

  static const Map<int, _ThemeInfo> _themes = {
    DateTime.monday: _ThemeInfo(
      categoryKu: 'Ziman',
      categoryTr: 'Dil',
      icon: Icons.translate_rounded,
      color: Color(0xFF1E5F47),
    ),
    DateTime.tuesday: _ThemeInfo(
      categoryKu: 'Çand',
      categoryTr: 'Kültür',
      icon: Icons.theater_comedy_rounded,
      color: Color(0xFFD65A31),
    ),
    DateTime.wednesday: _ThemeInfo(
      categoryKu: 'Dîrok',
      categoryTr: 'Tarih',
      icon: Icons.menu_book_rounded,
      color: Color(0xFF2B5C8F),
    ),
    DateTime.thursday: _ThemeInfo(
      categoryKu: 'Edebiyat',
      categoryTr: 'Edebiyat',
      icon: Icons.auto_stories_rounded,
      color: Color(0xFFE0A96D),
    ),
    DateTime.friday: _ThemeInfo(
      categoryKu: 'Cografya',
      categoryTr: 'Coğrafya',
      icon: Icons.public_rounded,
      color: Color(0xFF4C7063),
    ),
    DateTime.saturday: _ThemeInfo(
      categoryKu: 'Muzîk',
      categoryTr: 'Müzik',
      icon: Icons.music_note_rounded,
      color: Color(0xFFD4AF37),
    ),
    DateTime.sunday: _ThemeInfo(
      categoryKu: 'Tevlihev',
      categoryTr: 'Karma',
      icon: Icons.auto_awesome_rounded,
      color: Color(0xFFB83B5E),
    ),
  };

  static int get _today {
    return DateTime.now().weekday;
  }

  /// Returns the Kurmanci category name for today's theme.
  static String get todayCategory {
    final day = DateTime.now().weekday;
    return (_themes[day] ?? _themes[DateTime.monday]!).categoryKu;
  }

  _ThemeInfo get _currentTheme {
    final day = dayOverride ?? _today;
    return _themes[day] ?? _themes[DateTime.monday]!;
  }

  String get category => _currentTheme.categoryKu;

  IconData get icon => _currentTheme.icon;

  Color get color => _currentTheme.color;

  /// How long until the next theme changes (tomorrow at midnight).
  String _countdownText(bool ku) {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final remaining = tomorrow.difference(now);
    final hours = remaining.inHours;
    final minutes = remaining.inMinutes % 60;

    if (ku) {
      return 'Mijara din: $hours saet $minutes deqîqe';
    } else {
      return 'Sonraki tema: $hours saat $minutes dakika';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = _currentTheme;
    final categoryName = CategoryNames.localized(theme.categoryKu, isKu);
    final message = isKu
        ? 'Îro pirsên kategoriya $categoryName li benda te ne!'
        : 'Bugün $categoryName kategorisinde sorular seni bekliyor!';

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.card),
          splashColor: theme.color.withValues(alpha: 0.15),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.alphaBlend(
                    theme.color.withValues(alpha: 0.18),
                    AppTheme.surfaceColor(context),
                  ),
                  Color.alphaBlend(
                    theme.color.withValues(alpha: 0.06),
                    AppTheme.surfaceColor(context),
                  ),
                ],
              ),
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(
                color: theme.color.withValues(alpha: 0.35),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: theme.color.withValues(alpha: 0.10),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: KilimPatternPainter(
                        drawPattern: true,
                        color: theme.color,
                        opacity: 0.04,
                      ),
                    ),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header row with icon and label
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                theme.color,
                                theme.color.withValues(alpha: 0.7),
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: theme.color.withValues(alpha: 0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Icon(
                            theme.icon,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isKu ? 'Mijara Rojê' : 'Bugünün Teması',
                                style: AppTypography.caption.copyWith(
                                  color: theme.color,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.4,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                categoryName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.heading2.copyWith(
                                  color: AppTheme.textPrimaryColor(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: theme.color,
                          size: 24,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    // Message text
                    Text(
                      message,
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppTheme.textSubColor(context),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    // Countdown
                    Row(
                      children: [
                        Icon(
                          Icons.hourglass_empty_rounded,
                          size: 14,
                          color: AppTheme.textMutedColor(context),
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            _countdownText(isKu),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.caption.copyWith(
                              color: AppTheme.textMutedColor(context),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Internal data class for theme info.
class _ThemeInfo {
  const _ThemeInfo({
    required this.categoryKu,
    required this.categoryTr,
    required this.icon,
    required this.color,
  });

  final String categoryKu;
  final String categoryTr;
  final IconData icon;
  final Color color;
}
