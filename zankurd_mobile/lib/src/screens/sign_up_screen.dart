import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../animations/load_animations.dart';
import '../l10n/lang.dart';
import '../l10n/strings.dart';
import '../providers/auth_provider.dart';
import '../services/analytics_service.dart';
import '../theme/app_theme.dart';
import '../widgets/loading_overlay.dart';
import '../widgets/styled_button.dart';
import '../widgets/styled_input.dart';
import 'package:zankurd_mobile/src/theme/app_icons.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen>
    with TickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _usernameController = TextEditingController();

  // 2026-07-22 canlı UX denetimi: inline doğrulama
  final _step0FormKey = GlobalKey<FormState>();
  final _step1FormKey = GlobalKey<FormState>();
  final _emailFieldKey = GlobalKey<StyledInputFieldState>();
  final _passwordFieldKey = GlobalKey<StyledInputFieldState>();
  final _confirmPasswordFieldKey = GlobalKey<StyledInputFieldState>();
  final _usernameFieldKey = GlobalKey<StyledInputFieldState>();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  int _currentStep = 0;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      // Kademeli giriş animasyonu içeriği süre*0.5–0.95 aralığında
      // gösteriyor; 2000ms'de bu ~1.0–1.9sn boş ekran demekti
      // (2026-07-22 canlı UX denetimi). 900ms aynı kademeyi korur.
      duration: const Duration(milliseconds: 900),
      vsync: this,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _usernameController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  // 2026-07-22 canlı UX denetimi: inline doğrulama
  // SnackBar yerine alanların kendi validator'ı üzerinden hata gösterilir.
  bool _validateCurrentStep() {
    if (_currentStep == 0) {
      final emailOk = _emailFieldKey.currentState?.validate() ?? false;
      final passwordOk = _passwordFieldKey.currentState?.validate() ?? false;
      final confirmOk =
          _confirmPasswordFieldKey.currentState?.validate() ?? false;
      return emailOk && passwordOk && confirmOk;
    } else if (_currentStep == 1) {
      return _usernameFieldKey.currentState?.validate() ?? false;
    }
    return true;
  }

  void _nextStep() {
    // 2026-07-22 canlı UX denetimi: inline doğrulama
    if (!_validateCurrentStep()) return;

    setState(() {
      if (_currentStep < 2) {
        _currentStep++;
      }
    });
  }

  void _previousStep() {
    setState(() {
      if (_currentStep > 0) {
        _currentStep--;
      }
    });
  }

  Future<void> _signUp(AuthProvider authProvider) async {
    // 2026-07-22 canlı UX denetimi: inline doğrulama — tüm alanlar dolu mu son kontrol
    if (_emailController.text.isEmpty ||
        _passwordController.text.isEmpty ||
        _usernameController.text.isEmpty) {
      // Bu durum sadece kullanıcı review adımına geri dönüp alanları
      // temizlerse oluşabilir; inline hata gösterilemez çünkü o adım
      // form değil, bu yüzden SnackBar kullanıyoruz.
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.t(K.allFieldsRequired))));
      return;
    }

    LoadingOverlay.show(context, message: context.t(K.creatingAccount));

    final success = await authProvider.signUpWithEmail(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      displayName: _usernameController.text.trim(),
    );

    if (mounted) {
      LoadingOverlay.hide(context);

      if (success) {
        AnalyticsService.instance.logSignUp('email');
        if (authProvider.needsEmailConfirmation) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.t(K.accountCreated)),
              duration: const Duration(seconds: 5),
            ),
          );
        }
        Navigator.of(context).pop();
      } else if (authProvider.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.translateAuthError(authProvider.errorMessage!),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = !AppTheme.isLight(context);
    final glowColor1 = AppTheme.gold.withValues(alpha: isDark ? 0.08 : 0.05);
    final glowColor2 = isDark
        ? AppTheme.secondaryAccent.withValues(alpha: 0.12)
        : AppTheme.borderOf(context).withValues(alpha: 0.06);

    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;

    return Scaffold(
      body: Stack(
        children: [
          Container(decoration: BoxDecoration(color: AppTheme.bgOf(context))),
          // Soft Glow 1: Sağ Üst
          Positioned(
            top: -120,
            right: -120,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 250),
              opacity: keyboardOpen ? 0.0 : 1.0,
              child: Container(
                width: 320,
                height: 320,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [glowColor1, glowColor1.withValues(alpha: 0)],
                  ),
                ),
              ),
            ),
          ),
          // Soft Glow 2: Sol Alt
          Positioned(
            bottom: -140,
            left: -140,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 250),
              opacity: keyboardOpen ? 0.0 : 1.0,
              child: Container(
                width: 360,
                height: 360,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [glowColor2, glowColor2.withValues(alpha: 0)],
                  ),
                ),
              ),
            ),
          ),
          // Main content
          SafeArea(
            child: _AuthScrollFrame(
              child: Consumer<AuthProvider>(
                builder: (context, authProvider, _) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: AppSpacing.md),
                      ScaleTransition(
                        scale: LoadAnimationSequence.logoScaleAnimation(
                          _animationController,
                        ),
                        child: _ProgressIndicator(currentStep: _currentStep),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      FadeTransition(
                        opacity: LoadAnimationSequence.titleFadeAnimation(
                          _animationController,
                        ),
                        child: Transform.translate(
                          offset: Offset(
                            0,
                            LoadAnimationSequence.titleSlideAnimation(
                              _animationController,
                            ).value,
                          ),
                          child: _SignUpHeroBanner(
                            subtitle: _getStepSubtitle(context),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      _AuthFormPanel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            FadeTransition(
                              opacity:
                                  LoadAnimationSequence.formField1FadeAnimation(
                                    _animationController,
                                  ),
                              child: _buildStepContent(context),
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            Row(
                              children: [
                                // İlk adımda da geri çıkış olmalı: sihirbazın
                                // hiçbir adımında app bar/geri yoktu, tek
                                // çıkış alttaki metin bağlantısıydı
                                // (2026-07-22 canlı UX denetimi).
                                Expanded(
                                  child: OutlinedButton(
                                    key: const ValueKey('signup-back-button'),
                                    onPressed: authProvider.isLoading
                                        ? null
                                        : (_currentStep > 0
                                              ? _previousStep
                                              : () => Navigator.of(
                                                  context,
                                                ).maybePop()),
                                    style: OutlinedButton.styleFrom(
                                      minimumSize: const Size(
                                        double.infinity,
                                        48,
                                      ),
                                      side: BorderSide(
                                        color: AppTheme.borderColor(
                                          context,
                                        ).withValues(alpha: 0.8),
                                        width: 1.2,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                          AppRadius.lg,
                                        ),
                                      ),
                                    ),
                                    child: Text(context.t(K.backStep)),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: GeometricGradientButton(
                                    label: _currentStep == 2
                                        ? context.t(K.createAccount)
                                        : context.t(K.nextStep),
                                    icon: _currentStep == 2
                                        ? AppIcons.circleCheck
                                        : AppIcons.arrowRight,
                                    isLoading: authProvider.isLoading,
                                    onPressed: authProvider.isLoading
                                        ? null
                                        : (_currentStep == 2
                                              ? () => _signUp(authProvider)
                                              : _nextStep),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            Wrap(
                              alignment: WrapAlignment.center,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  context.t(K.haveAccountPrefix),
                                  style: AppTypography.bodyMedium.copyWith(
                                    color: AppTheme.textSubColor(context),
                                  ),
                                ),
                                InkWell(
                                  onTap: () => Navigator.of(context).pop(),
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.badge,
                                  ),
                                  child: Text(
                                    context.t(K.signIn),
                                    style: AppTypography.bodyMedium.copyWith(
                                      color: AppTheme.primaryGradientStart,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getStepSubtitle(BuildContext context) {
    switch (_currentStep) {
      case 0:
        return context.t(K.stepCredentials);
      case 1:
        return context.t(K.stepUsername);
      case 2:
        return context.t(K.stepReview);
      default:
        return '';
    }
  }

  Widget _buildStepContent(BuildContext context) {
    Widget stepWidget;
    switch (_currentStep) {
      case 0:
        // 2026-07-22 canlı UX denetimi: inline doğrulama — Form + autovalidateMode
        stepWidget = Form(
          key: _step0FormKey,
          child: Column(
            children: [
              StyledInputField(
                key: _emailFieldKey,
                label: context.t(K.emailAddress),
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                prefixIcon: AppIcons.envelope,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return context.t(K.emailRequired);
                  }
                  if (!value.contains('@')) {
                    return context.t(K.emailInvalid2);
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              FadeTransition(
                opacity: LoadAnimationSequence.formField2FadeAnimation(
                  _animationController,
                ),
                child: StyledInputField(
                  key: _passwordFieldKey,
                  label: context.t(K.passwordLabel),
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  prefixIcon: AppIcons.lock,
                  suffixIcon: _obscurePassword
                      ? AppIcons.eyeSlash
                      : AppIcons.eye,
                  suffixSemanticLabel: context.t(
                    _obscurePassword ? K.showPassword : K.hidePassword,
                  ),
                  onSuffixIconPressed: () {
                    setState(() => _obscurePassword = !_obscurePassword);
                  },
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  // Parola kuralı hint text olarak gösterilsin, hata beklemeden
                  hintText: context.t(K.passwordHintMin6),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return context.t(K.passwordRequired);
                    }
                    if (value.length < 6) {
                      return context.t(K.passwordMin6);
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(height: 20),
              StyledInputField(
                key: _confirmPasswordFieldKey,
                label: context.t(K.confirmPassword),
                controller: _confirmPasswordController,
                obscureText: _obscureConfirmPassword,
                prefixIcon: AppIcons.lock,
                suffixIcon: _obscureConfirmPassword
                    ? AppIcons.eyeSlash
                    : AppIcons.eye,
                suffixSemanticLabel: context.t(
                  _obscureConfirmPassword ? K.showPassword : K.hidePassword,
                ),
                onSuffixIconPressed: () {
                  setState(
                    () => _obscureConfirmPassword = !_obscureConfirmPassword,
                  );
                },
                autovalidateMode: AutovalidateMode.onUserInteraction,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return context.t(K.confirmPasswordRequired);
                  }
                  if (value != _passwordController.text) {
                    return context.t(K.passwordsMismatch);
                  }
                  return null;
                },
              ),
            ],
          ),
        );
        break;
      case 1:
        // 2026-07-22 canlı UX denetimi: inline doğrulama — Form + autovalidateMode
        stepWidget = Form(
          key: _step1FormKey,
          child: Column(
            children: [
              StyledInputField(
                key: _usernameFieldKey,
                label: context.t(K.username),
                controller: _usernameController,
                prefixIcon: AppIcons.user,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return context.t(K.usernameRequired);
                  }
                  if (value.length < 2) {
                    return context.t(K.usernameMin2);
                  }
                  return null;
                },
              ),
            ],
          ),
        );
        break;
      case 2:
        stepWidget = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ReviewItem(
              label: context.t(K.emailColon),
              value: _emailController.text,
            ),
            const SizedBox(height: 12),
            _ReviewItem(
              label: context.t(K.usernameColon),
              value: _usernameController.text,
            ),
            const SizedBox(height: 12),
            _ReviewItem(
              label: context.t(K.passwordColon),
              value: '*' * _passwordController.text.length,
            ),
          ],
        );
        break;
      default:
        stepWidget = const SizedBox.shrink();
    }

    if (_currentStep > 2) return stepWidget;

    return stepWidget;
  }
}

class _ProgressIndicator extends StatelessWidget {
  final int currentStep;

  const _ProgressIndicator({required this.currentStep});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _ProgressHexagon(number: 1, isActive: currentStep >= 0),
        const SizedBox(width: AppSpacing.xs),
        _ProgressHexagon(number: 2, isActive: currentStep >= 1),
        const SizedBox(width: AppSpacing.xs),
        _ProgressHexagon(number: 3, isActive: currentStep >= 2),
      ],
    );
  }
}

class _ProgressHexagon extends StatelessWidget {
  final int number;
  final bool isActive;

  const _ProgressHexagon({required this.number, required this.isActive});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeInOut,
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        gradient: isActive ? AppTheme.accentGradient : null,
        color: isActive
            ? null
            : AppTheme.surfaceHiColor(context).withValues(alpha: 0.5),
        border: Border.all(
          color: isActive
              ? Colors.white.withValues(alpha: 0.15)
              : AppTheme.borderColor(context).withValues(alpha: 0.6),
          width: 1.2,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: AppTheme.primaryGradientStart.withValues(alpha: 0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Center(
        child: Text(
          '$number',
          style: AppTypography.bodyLarge.copyWith(
            color: isActive ? Colors.white : AppTheme.textMutedColor(context),
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _ReviewItem extends StatelessWidget {
  final String label;
  final String value;

  const _ReviewItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.caption.copyWith(
            color: AppTheme.textSubColor(context),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            value,
            style: AppTypography.caption.copyWith(
              color: AppTheme.textPrimaryColor(context),
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _SignUpHeroBanner extends StatelessWidget {
  const _SignUpHeroBanner({required this.subtitle});

  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          // Pirs-inspired yeşil→turuncu compact welcome banner.
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppTheme.brand, AppTheme.brandDeep],
          ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
          boxShadow: AppTheme.elevatedShadow(AppTheme.brand),
        ),
        child: Stack(
          children: [
            Column(
              children: [
                Text(
                  context.t(K.createYourAccount),
                  style: AppTypography.heading1.copyWith(
                    color: Colors.white,
                    fontSize: 24,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  subtitle,
                  style: AppTypography.bodyMedium.copyWith(
                    color: Colors.white.withValues(alpha: 0.78),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthFormPanel extends StatelessWidget {
  const _AuthFormPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isLight = AppTheme.isLight(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isLight
            ? AppTheme.lightSurface
            : Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
          color: isLight
              ? AppTheme.lightBorder
              : Colors.white.withValues(alpha: 0.1),
        ),
        boxShadow: isLight ? AppTheme.cardShadow(context) : null,
      ),
      child: child,
    );
  }
}

class _AuthScrollFrame extends StatelessWidget {
  const _AuthScrollFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const edgePadding = 32.0;
        // 2026-07-22 canlı UX denetimi: dikey ortalama + padding düzeltmesi
        // minHeight clamp: klavye açıldığında negatif değer engellenir
        return SingleChildScrollView(
          padding: const EdgeInsets.all(edgePadding),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 420,
              minHeight: (constraints.maxHeight - (edgePadding * 2)).clamp(
                0.0,
                double.infinity,
              ),
            ),
            child: Center(child: child),
          ),
        );
      },
    );
  }
}
