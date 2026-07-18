import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../animations/load_animations.dart';
import '../l10n/lang.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/kilim_pattern_painter.dart';
import '../widgets/loading_overlay.dart';
import '../widgets/styled_button.dart';
import '../widgets/styled_input.dart';

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

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  int _currentStep = 0;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 2000),
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

  void _nextStep() {
    if (_currentStep == 0) {
      // Validate step 1: Email & Password
      if (_emailController.text.isEmpty) {
        _showError(context.s('E-peyam pêwîst e', 'E-posta gerekli'));
        return;
      }
      if (!_emailController.text.contains('@')) {
        _showError(
          context.s('E-peyameke derbasdar binivîse', 'Geçerli bir e-posta gir'),
        );
        return;
      }
      if (_passwordController.text.isEmpty) {
        _showError(context.s('Şîfre pêwîst e', 'Parola gerekli'));
        return;
      }
      if (_passwordController.text.length < 6) {
        _showError(
          context.s(
            'Şîfre divê herî kêm 6 tîp be',
            'Parola en az 6 karakter olmalı',
          ),
        );
        return;
      }
      if (_confirmPasswordController.text.isEmpty) {
        _showError(
          context.s('Piştrastkirina şîfreyê pêwîst e', 'Parola onayı gerekli'),
        );
        return;
      }
      if (_passwordController.text != _confirmPasswordController.text) {
        _showError(context.s('Şîfre li hev nakin', 'Parolalar eşleşmiyor'));
        return;
      }
    } else if (_currentStep == 1) {
      // Validate step 2: Username
      if (_usernameController.text.isEmpty) {
        _showError(
          context.s('Navê bikarhêner pêwîst e', 'Kullanıcı adı gerekli'),
        );
        return;
      }
      if (_usernameController.text.length < 2) {
        _showError(
          context.s(
            'Navê bikarhêner divê herî kêm 2 tîp be',
            'Kullanıcı adı en az 2 karakter olmalı',
          ),
        );
        return;
      }
    }

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

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _signUp(AuthProvider authProvider) async {
    // Final validation
    if (_emailController.text.isEmpty ||
        _passwordController.text.isEmpty ||
        _usernameController.text.isEmpty) {
      _showError(context.s('Hemû zelatên pêwîst in', 'Tüm alanlar gerekli'));
      return;
    }

    LoadingOverlay.show(
      context,
      message: context.s('Hesab tê afirandin...', 'Hesap oluşturuluyor...'),
    );

    final success = await authProvider.signUpWithEmail(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      displayName: _usernameController.text.trim(),
    );

    if (mounted) {
      LoadingOverlay.hide(context);

      if (success) {
        if (authProvider.needsEmailConfirmation) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                context.s(
                  'Hesab hat afirandin! Ji bo pejirandinê e-peyama xwe kontrol bike.',
                  'Hesap oluşturuldu! Doğrulamak için e-postanı kontrol et.',
                ),
              ),
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
                                if (_currentStep > 0)
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: authProvider.isLoading
                                          ? null
                                          : _previousStep,
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
                                      child: Text(context.s('Paş', 'Geri')),
                                    ),
                                  ),
                                if (_currentStep > 0)
                                  const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: GeometricGradientButton(
                                    label: _currentStep == 2
                                        ? context.s(
                                            'Hesab Biafirîne',
                                            'Hesap Oluştur',
                                          )
                                        : context.s('Pêş', 'İleri'),
                                    icon: _currentStep == 2
                                        ? Icons.check_circle_outline
                                        : Icons.arrow_forward,
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
                                  context.s(
                                    'Hesabê te jixwe heye? ',
                                    'Zaten hesabın var mı? ',
                                  ),
                                  style: AppTypography.bodyMedium.copyWith(
                                    color: AppTheme.textSubColor(context),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => Navigator.of(context).pop(),
                                  child: Text(
                                    context.s('Têkeve', 'Giriş Yap'),
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
        return context.s(
          'E-posta û şîfreyê xwe têkeve',
          'E-postanızı ve parolayı girin',
        );
      case 1:
        return context.s(
          'Navê bikarhênerê xwe hilbijêre',
          'Kullanıcı adınızı seçin',
        );
      case 2:
        return context.s(
          'Agahiya xwe nîqaş bikin',
          'Bilgilerinizi inceleyiniz',
        );
      default:
        return '';
    }
  }

  Widget _buildStepContent(BuildContext context) {
    Widget stepWidget;
    switch (_currentStep) {
      case 0:
        stepWidget = Column(
          children: [
            StyledInputField(
              label: context.s('Navnîşana e-peyamê', 'E-posta adresi'),
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              prefixIcon: Icons.email_outlined,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return context.s('E-peyam pêwîst e', 'E-posta gerekli');
                }
                if (!value.contains('@')) {
                  return context.s(
                    'E-peyameke derbasdar binivîse',
                    'Geçerli bir e-posta gir',
                  );
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
                label: context.s('Şîfre', 'Parola'),
                controller: _passwordController,
                obscureText: _obscurePassword,
                prefixIcon: Icons.lock_outlined,
                suffixIcon: _obscurePassword
                    ? Icons.visibility_off
                    : Icons.visibility,
                onSuffixIconPressed: () {
                  setState(() => _obscurePassword = !_obscurePassword);
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return context.s('Şîfre pêwîst e', 'Parola gerekli');
                  }
                  if (value.length < 6) {
                    return context.s(
                      'Şîfre divê herî kêm 6 tîp be',
                      'Parola en az 6 karakter olmalı',
                    );
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(height: 20),
            StyledInputField(
              label: context.s('Şîfreyê piştrast bike', 'Parolayı Onayla'),
              controller: _confirmPasswordController,
              obscureText: _obscureConfirmPassword,
              prefixIcon: Icons.lock_outlined,
              suffixIcon: _obscureConfirmPassword
                  ? Icons.visibility_off
                  : Icons.visibility,
              onSuffixIconPressed: () {
                setState(
                  () => _obscureConfirmPassword = !_obscureConfirmPassword,
                );
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return context.s(
                    'Piştrastkirina şîfreyê pêwîst e',
                    'Parola onayı gerekli',
                  );
                }
                if (value != _passwordController.text) {
                  return context.s(
                    'Şîfre li hev nakin',
                    'Parolalar eşleşmiyor',
                  );
                }
                return null;
              },
            ),
          ],
        );
        break;
      case 1:
        stepWidget = Column(
          children: [
            StyledInputField(
              label: context.s('Navê bikarhêner', 'Kullanıcı adı'),
              controller: _usernameController,
              prefixIcon: Icons.person_outline,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return context.s(
                    'Navê bikarhêner pêwîst e',
                    'Kullanıcı adı gerekli',
                  );
                }
                if (value.length < 2) {
                  return context.s(
                    'Navê bikarhêner divê herî kêm 2 tîp be',
                    'Kullanıcı adı en az 2 karakter olmalı',
                  );
                }
                return null;
              },
            ),
          ],
        );
        break;
      case 2:
        stepWidget = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ReviewItem(
              label: context.s('E-peyam:', 'E-posta:'),
              value: _emailController.text,
            ),
            const SizedBox(height: 12),
            _ReviewItem(
              label: context.s('Navê bikarhêner:', 'Kullanıcı adı:'),
              value: _usernameController.text,
            ),
            const SizedBox(height: 12),
            _ReviewItem(
              label: context.s('Şîfre:', 'Parola:'),
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
            colors: [AppTheme.playGreen, AppTheme.brandGreenDeep],
          ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
          boxShadow: AppTheme.elevatedShadow(AppTheme.playGreen),
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
            Column(
              children: [
                Text(
                  context.s('Hesabê xwe biafirîne', 'Hesabını oluştur'),
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
        final horizontalPadding = constraints.maxWidth < 380
            ? AppSpacing.md
            : AppSpacing.lg;
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            0,
            horizontalPadding,
            AppSpacing.lg,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: child,
            ),
          ),
        );
      },
    );
  }
}
