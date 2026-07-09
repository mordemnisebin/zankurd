import 'package:flutter/material.dart';

import '../data/zankurd_repository.dart';
import '../l10n/lang.dart';
import '../theme/app_theme.dart';
import '../utils/error_reporter.dart';
import '../widgets/app_logo.dart';
import '../widgets/kilim_pattern_painter.dart';
import '../widgets/styled_button.dart';

class ProfileNameGateScreen extends StatefulWidget {
  const ProfileNameGateScreen({
    required this.repository,
    required this.onCompleted,
    this.initialName,
    super.key,
  });

  final ZanKurdRepository repository;
  final String? initialName;
  final VoidCallback onCompleted;

  @override
  State<ProfileNameGateScreen> createState() => _ProfileNameGateScreenState();
}

class _ProfileNameGateScreenState extends State<ProfileNameGateScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final initial = _isDefaultName(widget.initialName)
        ? ''
        : widget.initialName;
    _controller = TextEditingController(text: initial ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _saving) return;
    final name = _controller.text.trim();
    setState(() => _saving = true);
    try {
      await widget.repository.updateProfileName(name);
      if (!mounted) return;
      widget.onCompleted();
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'profile name gate failed');
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.s(
              'Navê lîstikê nehat tomar kirin. Dîsa biceribîne.',
              'Oyuncu adı kaydedilemedi. Tekrar dene.',
            ),
          ),
        ),
      );
    }
  }

  static bool _isDefaultName(String? name) {
    final value = name?.trim();
    return value == null ||
        value.isEmpty ||
        value == 'ZanKurd Oyuncusu' ||
        value == 'ZanKurd Lîstikvan';
  }

  @override
  Widget build(BuildContext context) {
    final ku = context.isKu;

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxHeight < 860;

          return Column(
            children: [
              Expanded(
                flex: compact ? 42 : 45,
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(AppRadius.card),
                    bottomRight: Radius.circular(AppRadius.card),
                  ),
                  child: Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppTheme.secondaryAccent, AppTheme.bgDeep],
                      ),
                    ),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: IgnorePointer(
                            child: CustomPaint(
                              painter: KilimPatternPainter(
                                drawPattern: true,
                                color: Colors.white,
                                opacity: 0.05,
                              ),
                            ),
                          ),
                        ),
                        SafeArea(
                          bottom: false,
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(
                              AppSpacing.lg,
                              compact ? AppSpacing.md : AppSpacing.xl,
                              AppSpacing.lg,
                              AppSpacing.md,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                AppLogo(width: compact ? 76 : 88, onCard: true),
                                SizedBox(
                                  height: compact
                                      ? AppSpacing.sm
                                      : AppSpacing.lg,
                                ),
                                Text(
                                  ku
                                      ? 'Xweş hatî ZanKurd!'
                                      : 'ZanKurd\'a Hoş Geldin!',
                                  style: AppTypography.heading1.copyWith(
                                    color: Colors.white,
                                    fontSize: compact ? 24 : 28,
                                    height: 1.15,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.xxs),
                                Text(
                                  ku
                                      ? 'Hîn bibe, pêş bike û bi hevalan re bêhna xwe bide.'
                                      : 'Öğren, gelişin ve arkadaşlarınla eğlen.',
                                  style: AppTypography.bodyMedium.copyWith(
                                    color: Colors.white.withValues(alpha: 0.78),
                                    fontSize: compact ? 14 : 15,
                                    height: 1.4,
                                  ),
                                ),
                                SizedBox(
                                  height: compact
                                      ? AppSpacing.sm
                                      : AppSpacing.md,
                                ),
                                _HeroValueRow(
                                  icon: Icons.emoji_events_rounded,
                                  color: AppTheme.gold,
                                  text: ku
                                      ? 'Lîstikê û serlêderên bibike'
                                      : 'Oyunları tamamla, ödül kazan',
                                ),
                                const SizedBox(height: AppSpacing.xxs),
                                _HeroValueRow(
                                  icon: Icons.people_rounded,
                                  color: AppTheme.correct,
                                  text: ku
                                      ? 'Bi hevalan re pêşbikeve'
                                      : 'Arkadaşlarınla yarış',
                                ),
                                if (!compact) ...[
                                  const SizedBox(height: AppSpacing.xxs),
                                  _HeroValueRow(
                                    icon: Icons.local_fire_department_rounded,
                                    color: AppTheme.primaryGradientStart,
                                    text: ku
                                        ? 'Zincîra xwe biparêze'
                                        : 'Serini koru, zincirini devam ettir',
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: compact ? 58 : 55,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: AppTheme.backgroundGradient(context),
                  ),
                  child: SafeArea(
                    top: false,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.page,
                        AppSpacing.lg,
                        AppSpacing.page,
                        AppSpacing.lg,
                      ),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 430),
                        child: Container(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceColor(context).withValues(
                              alpha: AppTheme.isLight(context) ? 0.92 : 0.55,
                            ),
                            borderRadius: BorderRadius.circular(AppRadius.card),
                            border: Border.all(
                              color: AppTheme.borderColor(
                                context,
                              ).withValues(alpha: 0.45),
                            ),
                            boxShadow: AppTheme.softShadow(context),
                          ),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 4,
                                      height: 22,
                                      margin: const EdgeInsets.only(
                                        right: AppSpacing.sm,
                                      ),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(2),
                                        gradient: const LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            AppTheme.accent,
                                            AppTheme.primaryGradientEnd,
                                          ],
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        ku
                                            ? 'Navê te di lîstikê de çi be?'
                                            : 'Oyundaki adın ne olsun?',
                                        style: AppTypography.heading2.copyWith(
                                          color: AppTheme.textPrimaryColor(
                                            context,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: AppSpacing.xs),
                                Text(
                                  ku
                                      ? 'Ev nav di tabloya pêşderçûnê û odeyên serhêl de xuya dibe.'
                                      : 'Bu ad liderlik tablosunda ve çevrimiçi odalarda görünecek.',
                                  style: AppTypography.bodyMedium.copyWith(
                                    color: AppTheme.textMutedColor(context),
                                    height: 1.5,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.lg),
                                TextFormField(
                                  key: const ValueKey('player-name-field'),
                                  controller: _controller,
                                  textCapitalization: TextCapitalization.words,
                                  style: AppTypography.bodyLarge.copyWith(
                                    color: AppTheme.textPrimaryColor(context),
                                    fontWeight: FontWeight.w600,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: ku
                                        ? 'Mînak: Zelal'
                                        : 'Örn: Zelal',
                                    prefixIcon: Icon(
                                      Icons.person_outline,
                                      color: AppTheme.textMutedColor(context),
                                    ),
                                  ),
                                  validator: (value) {
                                    final name = value?.trim() ?? '';
                                    if (name.length < 2) {
                                      return ku
                                          ? 'Nav divê herî kêm 2 tîp be'
                                          : 'Ad en az 2 karakter olmalı';
                                    }
                                    if (name.length > 24) {
                                      return ku
                                          ? 'Nav divê herî zêde 24 tîp be'
                                          : 'Ad en fazla 24 karakter olmalı';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: AppSpacing.lg),
                                GeometricGradientButton(
                                  label: ku ? 'Dest Pê Bike' : 'Oyuna Başla',
                                  icon: Icons.arrow_forward_rounded,
                                  isLoading: _saving,
                                  onPressed: _saving ? null : _save,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _HeroValueRow extends StatelessWidget {
  const _HeroValueRow({
    required this.icon,
    required this.color,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(AppRadius.xs),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            text,
            style: AppTypography.bodyMedium.copyWith(
              color: Colors.white.withValues(alpha: 0.88),
              fontSize: 13,
              fontWeight: FontWeight.w500,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}
