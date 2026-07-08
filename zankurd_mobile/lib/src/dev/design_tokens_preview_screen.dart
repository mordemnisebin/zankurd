import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class DesignTokensPreviewScreen extends StatelessWidget {
  const DesignTokensPreviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeBg = AppTheme.lightBg;
    final themeText = AppTheme.lightTextPrimary;

    return Scaffold(
      backgroundColor: themeBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ZanKurd Design Tokens',
                style: AppTypography.display.copyWith(color: themeText),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Kültürel Modern Tasarım Sistemi Önizlemesi',
                style: AppTypography.bodyLarge.copyWith(color: AppTheme.lightTextSub),
              ),
              const SizedBox(height: AppSpacing.xl),

              // ── Renk Paleti ve Kontrast Uyumu ──────────────────────────
              _sectionHeader('1. Renk Paleti (Krem Zemin Üstü Kontrast)'),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.md,
                children: [
                  _ColorCard(
                    colorName: 'Primary (Coral)',
                    color: AppTheme.primaryGradientStart,
                    textColor: AppTheme.lightTextPrimary, // Koyu Yeşil (5.23:1 Kontrast)
                    desc: '0xFFE76F51\nKoyu Yeşil Yazı',
                  ),
                  _ColorCard(
                    colorName: 'Gold (Sun/Streak)',
                    color: AppTheme.gold,
                    textColor: AppTheme.lightTextPrimary, // Koyu Yeşil (9.68:1 Kontrast)
                    desc: '0xFFE9C46A\nKoyu Yeşil Yazı',
                  ),
                  _ColorCard(
                    colorName: 'Secondary Accent',
                    color: AppTheme.secondaryAccent,
                    textColor: Colors.white,
                    desc: '0xFF1E5F47\nBeyaz Yazı',
                  ),
                  _ColorCard(
                    colorName: 'Light BG (Krem)',
                    color: AppTheme.lightBg,
                    textColor: AppTheme.lightTextPrimary,
                    desc: '0xFFFAF7F0\nZemin Rengi',
                    hasBorder: true,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),

              // ── Buton Kombinasyonları (Doğru Kontrast) ─────────────────
              _sectionHeader('2. Buton Kombinasyonları (WCAG AA)'),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 52,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryGradientStart,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Text(
                        'Mercan + Koyu Yeşil (5.23:1)',
                        style: AppTypography.bodyLarge.copyWith(color: AppTheme.lightTextPrimary),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Container(
                      height: 52,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppTheme.gold,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Text(
                        'Gold + Koyu Yeşil (9.68:1)',
                        style: AppTypography.bodyLarge.copyWith(color: AppTheme.lightTextPrimary),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),

              // ── Tipografi Ölçeği ───────────────────────────────────────
              _sectionHeader('3. Tipografi Ölçeği'),
              const SizedBox(height: AppSpacing.md),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppTheme.lightSurface,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppTheme.lightBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Display (32pt, Heavy)',
                      style: AppTypography.display.copyWith(color: themeText),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Heading 1 (24pt, ExtraBold)',
                      style: AppTypography.heading1.copyWith(color: themeText),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Heading 2 (18pt, Bold)',
                      style: AppTypography.heading2.copyWith(color: themeText),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Body Large (16pt, SemiBold)',
                      style: AppTypography.bodyLarge.copyWith(color: themeText),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Body Medium (14pt, Medium)',
                      style: AppTypography.bodyMedium.copyWith(color: themeText),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Caption (12pt, Bold/Uppercase)',
                      style: AppTypography.caption.copyWith(color: themeText),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              // ── Radius & Spacing ──────────────────────────────────────
              _sectionHeader('4. Radius ve Spacing Skalası'),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: _RadiusSample(
                      name: 'Radius Small (12)',
                      radius: AppRadius.sm,
                      themeText: themeText,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: _RadiusSample(
                      name: 'Radius Medium (16)',
                      radius: AppRadius.md,
                      themeText: themeText,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: _RadiusSample(
                      name: 'Radius Large (28)',
                      radius: AppRadius.xl,
                      themeText: themeText,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Text(
      title,
      style: AppTypography.heading2.copyWith(
        color: AppTheme.lightTextPrimary,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _ColorCard extends StatelessWidget {
  const _ColorCard({
    required this.colorName,
    required this.color,
    required this.textColor,
    required this.desc,
    this.hasBorder = false,
  });

  final String colorName;
  final Color color;
  final Color textColor;
  final String desc;
  final bool hasBorder;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: hasBorder
            ? Border.all(color: Colors.black.withOpacity(0.12))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            colorName,
            style: AppTypography.caption.copyWith(color: textColor),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            desc,
            style: AppTypography.bodyMedium.copyWith(
              color: textColor.withOpacity(0.9),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _RadiusSample extends StatelessWidget {
  const _RadiusSample({
    required this.name,
    required this.radius,
    required this.themeText,
  });

  final String name;
  final double radius;
  final Color themeText;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppTheme.lightSurface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppTheme.lightBorder),
      ),
      child: Text(
        name,
        textAlign: TextAlign.center,
        style: AppTypography.caption.copyWith(color: themeText),
      ),
    );
  }
}
