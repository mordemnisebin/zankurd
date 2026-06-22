import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/lang.dart';
import '../../providers/theme_provider.dart';
import '../../theme/app_theme.dart';

class HomeHeader extends StatelessWidget {
  const HomeHeader({
    required this.coinBalance,
    required this.isKu,
    this.streak = 0,
    super.key,
  });

  final int? coinBalance;
  final bool isKu;
  final int streak;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            gradient: AppTheme.accentGradient,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: const Text(
            'ZK',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ZanKurd',
                style: TextStyle(
                  color: AppTheme.textPrimaryColor(context),
                  fontWeight: FontWeight.w800,
                  fontSize: 22,
                ),
              ),
              Text(
                isKu ? 'Pêşbirka Kurmancî' : 'Kürtçe Yarışması',
                style: TextStyle(
                  color: AppTheme.textMutedColor(context),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        if (streak > 0) ...[
          _StreakBadge(value: streak),
          const SizedBox(width: 8),
        ],
        _CoinBadge(value: coinBalance), // null → shows ···
        const SizedBox(width: 8),
        _LanguageQuickToggle(isKu: isKu),
        const SizedBox(width: 8),
        const _ThemeQuickToggle(),
      ],
    );
  }
}

class _LanguageQuickToggle extends StatelessWidget {
  const _LanguageQuickToggle({required this.isKu});

  final bool isKu;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: isKu ? 'Ziman' : 'Dil',
      child: InkWell(
        onTap: context.langProvider.toggle,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 42,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppTheme.surfaceHiColor(context),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.borderColor(context)),
          ),
          child: Text(
            isKu ? 'KU' : 'TR',
            style: TextStyle(
              color: AppTheme.textPrimaryColor(context),
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}

class _ThemeQuickToggle extends StatelessWidget {
  const _ThemeQuickToggle();

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    return Tooltip(
      message: 'Tema',
      child: InkWell(
        onTap: themeProvider.toggleDarkLight,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 38,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppTheme.surfaceHiColor(context),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.borderColor(context)),
          ),
          child: Icon(
            themeProvider.isDark
                ? Icons.dark_mode_outlined
                : Icons.light_mode_outlined,
            color: AppTheme.gold,
            size: 18,
          ),
        ),
      ),
    );
  }
}

class _StreakBadge extends StatelessWidget {
  const _StreakBadge({required this.value});

  final int value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.accent.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.local_fire_department,
            color: AppTheme.accent,
            size: 17,
          ),
          const SizedBox(width: 4),
          Text(
            '$value',
            style: const TextStyle(
              color: AppTheme.accent,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _CoinBadge extends StatelessWidget {
  const _CoinBadge({required this.value});

  final int? value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: AppTheme.goldGradient,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.monetization_on, color: Colors.white, size: 17),
          const SizedBox(width: 5),
          Text(
            value != null ? '$value' : '···',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
