import 'package:flutter/material.dart';

import '../data/zankurd_repository.dart';
import '../l10n/lang.dart';
import '../l10n/strings.dart';
import '../theme/app_theme.dart';
import '../utils/error_reporter.dart';
import '../widgets/app_logo.dart';
import '../widgets/styled_button.dart';
import 'package:zankurd_mobile/src/theme/app_icons.dart';

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
  String? _saveError;

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
    // Klavye kapanmadan hata gösterilemez: `SnackBarBehavior.floating`
    // kutuyu ekranın altına koyar ve açık klavye tam orayı örter. Oyuncu
    // "Dest pê bike"ye basıyor, yazım sunucuya gitmiyor, hata mesajı
    // klavyenin arkasında doğup ölüyor — ekranda hiçbir şey olmuyor
    // (2026-07-31, sahibin iPhone ekran görüntüleri).
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      await widget.repository.updateProfileName(name);
      if (!mounted) return;
      widget.onCompleted();
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'profile name gate failed');
      if (!mounted) return;
      // Hata artık formun içinde, kalıcı olarak duruyor. Geçici bir
      // SnackBar burada yanlış araçtı: üç saniye sonra kaybolur ve geriye
      // açıklamasız bir tıkanma bırakır.
      setState(() {
        _saving = false;
        _saveError = context.t(K.nameGateSaveFailed);
      });
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
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxHeight < 860;

          return Column(
            children: [
              // 2026-07-23 M23: hero sabit flex (42-45%) alıyordu ama
              // içeriği (logo+başlık+2-3 satır) çok daha az yer kaplıyor —
              // alt ~125px'i tamamen boş kalıyordu. Artık içerik kadar yer
              // kaplıyor, kalan alan forma (Expanded) gidiyor.
              ClipRRect(
                key: const ValueKey('profile-name-gate-hero'),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(AppRadius.card),
                  bottomRight: Radius.circular(AppRadius.card),
                ),
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    // Pirs-inspired büyük turuncu karşılama header'ı.
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppTheme.brand, AppTheme.brandDeep],
                    ),
                  ),
                  child: Stack(
                    children: [
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
                              AppLogo(
                                width: compact ? 64 : 72,
                                onBrandSurface: true,
                              ),
                              SizedBox(
                                height: compact ? AppSpacing.sm : AppSpacing.lg,
                              ),
                              Text(
                                context.t(K.nameGateWelcome),
                                style: AppTypography.heading1.copyWith(
                                  color: Colors.white,
                                  fontSize: compact ? 24 : 28,
                                  height: 1.15,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xxs),
                              Text(
                                context.t(K.nameGateSubtitle),
                                style: AppTypography.bodyMedium.copyWith(
                                  color: Colors.white.withValues(alpha: 0.78),
                                  fontSize: compact ? 14 : 15,
                                  height: 1.4,
                                ),
                              ),
                              SizedBox(
                                height: compact ? AppSpacing.sm : AppSpacing.md,
                              ),
                              _HeroValueRow(
                                icon: AppIcons.trophy,
                                color: Colors.white,
                                text: context.t(K.nameGateValueQuests),
                              ),
                              const SizedBox(height: AppSpacing.xxs),
                              _HeroValueRow(
                                icon: AppIcons.peopleGroup,
                                color: Colors.white,
                                text: context.t(K.nameGateValueFriends),
                              ),
                              if (!compact) ...[
                                const SizedBox(height: AppSpacing.xxs),
                                _HeroValueRow(
                                  icon: AppIcons.fire,
                                  color: Colors.white,
                                  text: context.t(K.nameGateValueStreak),
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
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: AppTheme.backgroundGradient(context),
                  ),
                  child: SafeArea(
                    top: false,
                    // 2026-07-23 M23 devamı: hero sıkılaştırılınca form
                    // kartının altında da boşluk kaldığı canlı testte
                    // görüldü — kart kısa kaldığında Expanded alanının
                    // tamamını doldurmuyordu. Aynı minHeight+Center
                    // deseniyle kart artık kalan alanda ortalanıyor.
                    child: LayoutBuilder(
                      builder: (context, formConstraints) {
                        return SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.page,
                            AppSpacing.lg,
                            AppSpacing.page,
                            AppSpacing.lg,
                          ),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight:
                                  (formConstraints.maxHeight -
                                          (AppSpacing.lg * 2))
                                      .clamp(0.0, double.infinity),
                            ),
                            child: Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 430,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.all(AppSpacing.md),
                                  decoration: BoxDecoration(
                                    color: AppTheme.surfaceColor(context)
                                        .withValues(
                                          alpha: AppTheme.isLight(context)
                                              ? 0.92
                                              : 0.55,
                                        ),
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.card,
                                    ),
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
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
                                                borderRadius:
                                                    BorderRadius.circular(2),
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
                                                context.t(K.nameGateQuestion),
                                                style: AppTypography.heading2
                                                    .copyWith(
                                                      color:
                                                          AppTheme.textPrimaryColor(
                                                            context,
                                                          ),
                                                    ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: AppSpacing.xs),
                                        Text(
                                          context.t(K.nameGateHelp),
                                          style: AppTypography.bodyMedium
                                              .copyWith(
                                                color: AppTheme.textMutedColor(
                                                  context,
                                                ),
                                                height: 1.5,
                                              ),
                                        ),
                                        const SizedBox(height: AppSpacing.lg),
                                        TextFormField(
                                          key: const ValueKey(
                                            'player-name-field',
                                          ),
                                          controller: _controller,
                                          // Hata yalnız Form.validate() ile
                                          // güncelleniyordu: geçerli bir ad yazıldıktan
                                          // sonra da kırmızı kenarlık ve "en az 2
                                          // karakter" uyarısı ekranda kalıyordu
                                          // (2026-07-22 canlı UX denetimi).
                                          autovalidateMode: AutovalidateMode
                                              .onUserInteraction,
                                          textCapitalization:
                                              TextCapitalization.words,
                                          style: AppTypography.bodyLarge
                                              .copyWith(
                                                color:
                                                    AppTheme.textPrimaryColor(
                                                      context,
                                                    ),
                                                fontWeight: FontWeight.w600,
                                              ),
                                          decoration: InputDecoration(
                                            hintText: context.t(K.nameGateHint),
                                            prefixIcon: Icon(
                                              AppIcons.user,
                                              color: AppTheme.textMutedColor(
                                                context,
                                              ),
                                            ),
                                          ),
                                          validator: (value) {
                                            final name = value?.trim() ?? '';
                                            if (name.length < 2) {
                                              return context.t(K.nameMinLength);
                                            }
                                            if (name.length > 24) {
                                              return context.t(K.nameMaxLength);
                                            }
                                            return null;
                                          },
                                        ),
                                        if (_saveError != null) ...[
                                          const SizedBox(height: AppSpacing.md),
                                          Container(
                                            key: const ValueKey(
                                              'name-gate-save-error',
                                            ),
                                            width: double.infinity,
                                            padding: const EdgeInsets.all(
                                              AppSpacing.md,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppTheme.wrong.withValues(
                                                alpha: 0.12,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(
                                                    AppRadius.md,
                                                  ),
                                              border: Border.all(
                                                color: AppTheme.wrong
                                                    .withValues(alpha: 0.4),
                                              ),
                                            ),
                                            child: Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Icon(
                                                  AppIcons.triangleExclamation,
                                                  size: 20,
                                                  color:
                                                      AppColors.readableAccent(
                                                        context,
                                                        AppTheme.wrong,
                                                      ),
                                                ),
                                                const SizedBox(width: 10),
                                                Expanded(
                                                  child: Text(
                                                    _saveError!,
                                                    style: AppTypography
                                                        .bodyMedium
                                                        .copyWith(
                                                          color:
                                                              AppTheme.textPrimaryColor(
                                                                context,
                                                              ),
                                                          height: 1.45,
                                                        ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                        const SizedBox(height: AppSpacing.lg),
                                        GeometricGradientButton(
                                          label: context.t(K.nameGateCta),
                                          icon: AppIcons.arrowRight,
                                          isLoading: _saving,
                                          onPressed: _saving ? null : _save,
                                        ),
                                        const SizedBox(height: AppSpacing.xs),
                                        // 2026-07-23 UX: isim artık zorunlu değil;
                                        // kullanıcı varsayılan adla geçip sonra
                                        // profilden değiştirebilir (giriş sürtünmesi ↓).
                                        TextButton(
                                          onPressed: _saving
                                              ? null
                                              : widget.onCompleted,
                                          child: Text(
                                            context.t(K.nameGateSkip),
                                            style: AppTypography.bodyMedium
                                                .copyWith(
                                                  color:
                                                      AppTheme.textMutedColor(
                                                        context,
                                                      ),
                                                  fontWeight: FontWeight.w600,
                                                ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
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
