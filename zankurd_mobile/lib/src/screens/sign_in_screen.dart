import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../animations/load_animations.dart';
import '../l10n/lang.dart';
import '../l10n/strings.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import '../utils/app_route.dart';
import '../widgets/app_logo.dart';
import '../widgets/loading_overlay.dart';
import '../widgets/styled_button.dart';
import '../widgets/styled_input.dart';
import 'sign_up_screen.dart';
import 'package:zankurd_mobile/src/theme/app_icons.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen>
    with TickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      // Kademeli giriş animasyonu içeriği süre*0.5–0.95 aralığında
      // gösteriyor; 900ms'de bu ~0.45–0.85sn boş ekran demekti. Faz 4:
      // ilk-değer hızı için 500ms'ye çekildi (aynı kademe korunur).
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _signIn(AuthProvider authProvider) async {
    // StyledInputField, TextField kullandığı için Form.validate() ile
    // tetiklenmez. Boş alan kontrolü manuel yapılır.
    if (_emailController.text.trim().isEmpty) {
      _showAuthError(context.t(K.emailRequired));
      return;
    }
    if (_passwordController.text.isEmpty) {
      _showAuthError(context.t(K.passwordRequired));
      return;
    }
    // Kısa şifrede "pêwîst e" (gerekli) mesajı yanlış etiketti; min-length
    // durumunda doğru mesajı göster (KU+TR).
    if (_passwordController.text.length < 6) {
      _showAuthError(context.t(K.passwordMin6));
      return;
    }
    if (_formKey.currentState?.validate() != true) return;

    LoadingOverlay.show(context, message: context.t(K.signingIn));

    final success = await authProvider.signInWithEmail(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );

    if (mounted) {
      LoadingOverlay.hide(context);

      if (!success && authProvider.errorMessage != null) {
        _showAuthError(authProvider.errorMessage!);
      }
    }
  }

  Future<void> _signInWithGoogle(AuthProvider authProvider) async {
    LoadingOverlay.show(context, message: context.t(K.connectingGoogle));

    final success = await authProvider.signInWithGoogle();

    if (mounted) {
      LoadingOverlay.hide(context);

      if (!success && authProvider.errorMessage != null) {
        _showAuthError(authProvider.errorMessage!);
      }
    }
  }

  Future<void> _signInWithApple(AuthProvider authProvider) async {
    LoadingOverlay.show(context, message: context.t(K.connectingApple));

    final success = await authProvider.signInWithApple();

    if (mounted) {
      LoadingOverlay.hide(context);

      if (!success && authProvider.errorMessage != null) {
        _showAuthError(authProvider.errorMessage!);
      }
    }
  }

  Future<void> _signInAsGuest(AuthProvider authProvider) async {
    LoadingOverlay.show(context, message: context.t(K.signingInGuest));

    final success = await authProvider.signInAsGuest();

    if (mounted) {
      LoadingOverlay.hide(context);

      if (!success && authProvider.errorMessage != null) {
        _showAuthError(authProvider.errorMessage!);
      }
    }
  }

  Future<void> _resetPassword(AuthProvider authProvider) async {
    final email = _emailController.text.trim();
    if (!_isValidEmail(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t(K.enterValidEmailFirst))),
      );
      return;
    }

    LoadingOverlay.show(context, message: context.t(K.sendingReset));

    final success = await authProvider.resetPassword(email);

    if (!mounted) return;
    LoadingOverlay.hide(context);

    final message = success
        ? context.t(K.resetSent)
        : (authProvider.errorMessage != null
              ? context.translateAuthError(authProvider.errorMessage!)
              : context.t(K.resetFailed));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  bool _isValidEmail(String value) {
    return value.contains('@') && value.contains('.');
  }

  void _showAuthError(String message) {
    final localized = context.translateAuthError(message);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(localized), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final compact = screenSize.height < 900;
    // Kompakt düzen boyut sabitleri — M-8 denetim düzeltmesi.
    // Her sabitin anlamı yorumda belgelenmiştir; ileride tek noktadan değişir.
    const double kLogoWidthCompact = 71.0; // Kısa ekranda küçültülmüş logo
    const double kLogoWidthNormal = 120.0; // Normal ekranda tam logo
    const double kAltGapCompact = 8.0; // "Veya" bölümü üst boşluk (kısa)
    const double kAltGapNormal = 20.0; // "Veya" bölümü üst boşluk (tam)
    const double kBottomGapCompact = 14.0; // Alt misafir butonu boşluğu (kısa)
    const double kBottomGapNormal = 32.0; // Alt misafir butonu boşluğu (tam)

    // Beyaz logo kutusu %40 küçültüldü (118→71, 200→120).
    final logoWidth = compact ? kLogoWidthCompact : kLogoWidthNormal;
    final topGap = compact ? 0.0 : AppSpacing.md;
    final actionGap = compact ? AppSpacing.sm : AppSpacing.lg;
    final altGap = compact ? kAltGapCompact : kAltGapNormal;
    final bottomGap = compact ? kBottomGapCompact : kBottomGapNormal;
    final authInputLabelStyle = TextStyle(
      color: AppTheme.textPrimaryColor(context),
      fontWeight: FontWeight.w700,
    );
    final authInputTextStyle = TextStyle(
      color: AppTheme.textPrimaryColor(context),
      fontWeight: FontWeight.w600,
    );

    final isDark = !AppTheme.isLight(context);
    final glowColor1 = AppTheme.gold.withValues(alpha: isDark ? 0.08 : 0.05);
    final glowColor2 = isDark
        ? AppTheme.secondaryAccent.withValues(alpha: 0.12)
        : AppTheme.borderOf(context).withValues(alpha: 0.06);

    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;

    return Scaffold(
      body: Stack(
        children: [
          // Context-aware düz zemin (light: lightBg, dark: bg)
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
          Positioned.fill(
            child: SafeArea(
              child: _AuthScrollFrame(
                builder: (context, isWide) => Consumer<AuthProvider>(
                  builder: (context, authProvider, _) {
                    final denseWide =
                        isWide &&
                        (screenSize.height < 520 ||
                            screenSize.width > screenSize.height);
                    final wideGap = denseWide ? 4.0 : 16.0;
                    final wideButtonGap = denseWide ? 4.0 : 12.0;
                    final wideLogoTop = denseWide ? 24.0 : 40.0;

                    if (isWide) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 5,
                            child: Padding(
                              padding: EdgeInsets.only(top: wideLogoTop),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  ScaleTransition(
                                    scale:
                                        LoadAnimationSequence.logoScaleAnimation(
                                          _animationController,
                                        ),
                                    child: Center(
                                      child: AppLogo(
                                        width: logoWidth * 1.2,
                                        onCard: true,
                                        cardRadius: AppRadius.card,
                                        cardPadding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 10,
                                        ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    height: denseWide
                                        ? AppSpacing.xs
                                        : AppSpacing.lg,
                                  ),
                                  FadeTransition(
                                    opacity:
                                        LoadAnimationSequence.titleFadeAnimation(
                                          _animationController,
                                        ),
                                    child: Transform.translate(
                                      offset: Offset(
                                        0,
                                        LoadAnimationSequence.titleSlideAnimation(
                                          _animationController,
                                        ).value,
                                      ),
                                      child: _SignInHeroBanner(
                                        compact: denseWide,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 48),
                          Expanded(
                            flex: 6,
                            child: _AuthFormPanel(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Align(
                                    alignment: Alignment.topRight,
                                    child: ScaleTransition(
                                      scale:
                                          LoadAnimationSequence.logoScaleAnimation(
                                            _animationController,
                                          ),
                                      child: _LanguageToggle(),
                                    ),
                                  ),
                                  SizedBox(height: wideGap),
                                  _GoogleSignInButton(
                                    dense: denseWide,
                                    onPressed: authProvider.isLoading
                                        ? null
                                        : () => _signInWithGoogle(authProvider),
                                  ),
                                  if (_AppleSignInButton
                                      .isSupportedPlatform) ...[
                                    SizedBox(height: denseWide ? 4 : 8),
                                    _AppleSignInButton(
                                      dense: denseWide,
                                      onPressed: authProvider.isLoading
                                          ? null
                                          : () =>
                                                _signInWithApple(authProvider),
                                    ),
                                  ],
                                  SizedBox(height: denseWide ? 4 : 8),
                                  Center(
                                    child: _GuestSignInLink(
                                      onPressed: authProvider.isLoading
                                          ? null
                                          : () => _signInAsGuest(authProvider),
                                    ),
                                  ),
                                  SizedBox(height: wideButtonGap),
                                  const _EmailSectionDivider(),
                                  ...[
                                    SizedBox(height: wideButtonGap),
                                    FadeTransition(
                                      opacity:
                                          LoadAnimationSequence.formField1FadeAnimation(
                                            _animationController,
                                          ),
                                      child: Form(
                                        key: _formKey,
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            StyledInputField(
                                              autovalidateMode: AutovalidateMode
                                                  .onUserInteraction,
                                              label: context.t(K.emailAddress),
                                              labelStyle: authInputLabelStyle,
                                              inputTextStyle:
                                                  authInputTextStyle,
                                              controller: _emailController,
                                              keyboardType:
                                                  TextInputType.emailAddress,
                                              prefixIcon: AppIcons.envelope,
                                              validator: (value) {
                                                if (value == null ||
                                                    value.isEmpty) {
                                                  return context.t(
                                                    K.emailRequired,
                                                  );
                                                }
                                                if (!value.contains('@')) {
                                                  return context.t(
                                                    K.emailInvalid2,
                                                  );
                                                }
                                                return null;
                                              },
                                            ),
                                            SizedBox(height: wideGap),
                                            FadeTransition(
                                              opacity:
                                                  LoadAnimationSequence.formField2FadeAnimation(
                                                    _animationController,
                                                  ),
                                              child: StyledInputField(
                                                autovalidateMode:
                                                    AutovalidateMode
                                                        .onUserInteraction,
                                                label: context.t(
                                                  K.passwordLabel,
                                                ),
                                                labelStyle: authInputLabelStyle,
                                                inputTextStyle:
                                                    authInputTextStyle,
                                                controller: _passwordController,
                                                obscureText: _obscurePassword,
                                                prefixIcon: AppIcons.lock,
                                                suffixIcon: _obscurePassword
                                                    ? AppIcons.eyeSlash
                                                    : AppIcons.eye,
                                                onSuffixIconPressed: () {
                                                  setState(
                                                    () => _obscurePassword =
                                                        !_obscurePassword,
                                                  );
                                                },
                                                validator: (value) {
                                                  if (value == null ||
                                                      value.isEmpty) {
                                                    return context.t(
                                                      K.passwordRequired,
                                                    );
                                                  }
                                                  if (value.length < 6) {
                                                    return context.t(
                                                      K.passwordMin6,
                                                    );
                                                  }
                                                  return null;
                                                },
                                              ),
                                            ),
                                            SizedBox(height: denseWide ? 0 : 8),
                                            Align(
                                              alignment: Alignment.centerRight,
                                              child: TextButton(
                                                onPressed:
                                                    authProvider.isLoading
                                                    ? null
                                                    : () => _resetPassword(
                                                        authProvider,
                                                      ),
                                                // 2026-07-22 canlı UX denetimi: CTA erişilebilirlik düzeltmesi
                                                child: ExcludeSemantics(
                                                  child: Text(
                                                    context.t(K.forgotPassword),
                                                    style: AppTypography
                                                        .bodyMedium
                                                        .copyWith(
                                                          color:
                                                              AppTheme.textSubColor(
                                                                context,
                                                              ),
                                                          fontSize: 13,
                                                        ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    SizedBox(height: wideButtonGap),
                                    FadeTransition(
                                      opacity:
                                          LoadAnimationSequence.buttonFadeAnimation(
                                            _animationController,
                                          ),
                                      child: ScaleTransition(
                                        scale:
                                            LoadAnimationSequence.buttonScaleAnimation(
                                              _animationController,
                                            ),
                                        child: GeometricGradientButton(
                                          label: context.t(K.signIn),
                                          icon: AppIcons.rightToBracket,
                                          isLoading: authProvider.isLoading,
                                          onPressed: authProvider.isLoading
                                              ? null
                                              : () => _signIn(authProvider),
                                        ),
                                      ),
                                    ),
                                  ],
                                  SizedBox(height: wideGap),
                                  Wrap(
                                    alignment: WrapAlignment.center,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      Text(
                                        context.t(K.noAccountPrefix),
                                        style: AppTypography.bodyMedium
                                            .copyWith(
                                              color: AppTheme.textSubColor(
                                                context,
                                              ),
                                            ),
                                      ),
                                      InkWell(
                                        onTap: () {
                                          Navigator.of(context).push(
                                            AppRoute.to(const SignUpScreen()),
                                          );
                                        },
                                        borderRadius: BorderRadius.circular(
                                          AppRadius.badge,
                                        ),
                                        child: Text(
                                          context.t(K.signUp),
                                          style: AppTypography.bodyMedium
                                              .copyWith(
                                                color: AppColors.readableAccent(
                                                  context,
                                                  AppTheme.accent,
                                                ),
                                                fontWeight: FontWeight.w700,
                                              ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Language toggle - top right
                        Align(
                          alignment: Alignment.topRight,
                          child: ScaleTransition(
                            scale: LoadAnimationSequence.logoScaleAnimation(
                              _animationController,
                            ),
                            child: _LanguageToggle(),
                          ),
                        ),
                        SizedBox(height: topGap),
                        // Logo
                        ScaleTransition(
                          scale: LoadAnimationSequence.logoScaleAnimation(
                            _animationController,
                          ),
                          child: Center(
                            child: AppLogo(
                              width: logoWidth,
                              onCard: true,
                              cardRadius: AppRadius.card,
                              cardPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(
                          height: compact ? AppSpacing.sm : AppSpacing.lg,
                        ),
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
                            child: _SignInHeroBanner(compact: compact),
                          ),
                        ),
                        SizedBox(
                          height: compact ? AppSpacing.md : AppSpacing.lg,
                        ),
                        _AuthFormPanel(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _GoogleSignInButton(
                                onPressed: authProvider.isLoading
                                    ? null
                                    : () => _signInWithGoogle(authProvider),
                              ),
                              if (_AppleSignInButton.isSupportedPlatform) ...[
                                const SizedBox(height: 8),
                                _AppleSignInButton(
                                  onPressed: authProvider.isLoading
                                      ? null
                                      : () => _signInWithApple(authProvider),
                                ),
                              ],
                              const SizedBox(height: 8),
                              // Misafir girişi: ikincil eylem, outlined buton
                              // (tek baskın CTA = Google, altta belirgin seçenek).
                              Center(
                                child: _GuestSignInLink(
                                  onPressed: authProvider.isLoading
                                      ? null
                                      : () => _signInAsGuest(authProvider),
                                ),
                              ),
                              SizedBox(height: actionGap),
                              const _EmailSectionDivider(),
                              ...[
                                SizedBox(height: altGap),
                                // Form fields with fade animations
                                FadeTransition(
                                  opacity:
                                      LoadAnimationSequence.formField1FadeAnimation(
                                        _animationController,
                                      ),
                                  child: Form(
                                    key: _formKey,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        StyledInputField(
                                          autovalidateMode: AutovalidateMode
                                              .onUserInteraction,
                                          label: context.t(K.emailAddress),
                                          labelStyle: authInputLabelStyle,
                                          inputTextStyle: authInputTextStyle,
                                          controller: _emailController,
                                          keyboardType:
                                              TextInputType.emailAddress,
                                          prefixIcon: AppIcons.envelope,
                                          validator: (value) {
                                            if (value == null ||
                                                value.isEmpty) {
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
                                          opacity:
                                              LoadAnimationSequence.formField2FadeAnimation(
                                                _animationController,
                                              ),
                                          child: StyledInputField(
                                            autovalidateMode: AutovalidateMode
                                                .onUserInteraction,
                                            label: context.t(K.passwordLabel),
                                            labelStyle: authInputLabelStyle,
                                            inputTextStyle: authInputTextStyle,
                                            controller: _passwordController,
                                            obscureText: _obscurePassword,
                                            prefixIcon: AppIcons.lock,
                                            suffixIcon: _obscurePassword
                                                ? AppIcons.eyeSlash
                                                : AppIcons.eye,
                                            onSuffixIconPressed: () {
                                              setState(
                                                () => _obscurePassword =
                                                    !_obscurePassword,
                                              );
                                            },
                                            validator: (value) {
                                              if (value == null ||
                                                  value.isEmpty) {
                                                return context.t(
                                                  K.passwordRequired,
                                                );
                                              }
                                              if (value.length < 6) {
                                                return context.t(
                                                  K.passwordMin6,
                                                );
                                              }
                                              return null;
                                            },
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        Align(
                                          alignment: Alignment.centerRight,
                                          child: TextButton(
                                            onPressed: authProvider.isLoading
                                                ? null
                                                : () => _resetPassword(
                                                    authProvider,
                                                  ),
                                            // 2026-07-22 canlı UX denetimi: CTA erişilebilirlik düzeltmesi
                                            child: ExcludeSemantics(
                                              child: Text(
                                                context.t(K.forgotPassword),
                                                style: TextStyle(
                                                  color: AppTheme.textSubColor(
                                                    context,
                                                  ),
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                SizedBox(height: actionGap),
                                // Sign In Button with animations
                                FadeTransition(
                                  opacity:
                                      LoadAnimationSequence.buttonFadeAnimation(
                                        _animationController,
                                      ),
                                  child: ScaleTransition(
                                    scale:
                                        LoadAnimationSequence.buttonScaleAnimation(
                                          _animationController,
                                        ),
                                    child: GeometricGradientButton(
                                      label: context.t(K.signIn),
                                      icon: AppIcons.rightToBracket,
                                      isLoading: authProvider.isLoading,
                                      onPressed: authProvider.isLoading
                                          ? null
                                          : () => _signIn(authProvider),
                                    ),
                                  ),
                                ),
                              ],
                              SizedBox(height: compact ? 16 : 24),
                              // Sign Up link
                              Wrap(
                                alignment: WrapAlignment.center,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    context.t(K.noAccountPrefix),
                                    style: AppTypography.bodyMedium.copyWith(
                                      color: AppTheme.textSubColor(context),
                                    ),
                                  ),
                                  InkWell(
                                    onTap: () {
                                      Navigator.of(
                                        context,
                                      ).push(AppRoute.to(const SignUpScreen()));
                                    },
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.badge,
                                    ),
                                    child: Text(
                                      context.t(K.signUp),
                                      style: AppTypography.bodyMedium.copyWith(
                                        color: AppColors.readableAccent(
                                          context,
                                          AppTheme.accent,
                                        ),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: bottomGap),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SignInHeroBanner extends StatelessWidget {
  const _SignInHeroBanner({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(compact ? AppSpacing.md : AppSpacing.lg),
        decoration: BoxDecoration(
          // 2026-07-24 canlı denetim: banner, "Têkeve" butonu ve KU/TR çipi
          // aynı anda turuncuydu — ekranda üç eşit ağırlıkta turuncu kütle
          // vardı. Banner kimlik rengine (Kesk) alındı; turuncu yalnız
          // birincil eylemde kalır.
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppTheme.culturalBrandBg, Color(0xFF1E6B4C)],
          ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
        ),
        child: Stack(
          children: [
            Column(
              children: [
                Text(
                  context.t(K.welcomeTitle),
                  style: AppTypography.heading1.copyWith(
                    color: Colors.white,
                    fontSize: compact ? 22 : 26,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  context.t(K.welcomeSubtitle),
                  style: AppTypography.bodyMedium.copyWith(
                    color: Colors.white.withValues(alpha: 0.78),
                    fontSize: compact ? 13 : 14,
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

class _GoogleSignInButton extends StatelessWidget {
  const _GoogleSignInButton({required this.onPressed, this.dense = false});

  final VoidCallback? onPressed;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return IgnorePointer(
      ignoring: !enabled,
      child: Opacity(
        opacity: enabled ? 1 : 0.55,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.14),
                blurRadius: 16,
                offset: const Offset(0, 6),
                spreadRadius: -2,
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              onTap: onPressed,
              child: Container(
                height: dense ? 48 : 54,
                padding: EdgeInsets.symmetric(horizontal: dense ? 12 : 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'G',
                      style: TextStyle(
                        color: AppTheme.accent,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'Rubik',
                        fontSize: dense ? 20 : 24,
                      ),
                    ),
                    SizedBox(width: dense ? 8 : 12),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          context.t(K.signInGoogle),
                          maxLines: 1,
                          style: TextStyle(
                            color: AppTheme.bgDeep,
                            fontWeight: FontWeight.w800,
                            fontSize: dense ? 14 : 16,
                            letterSpacing: 0.1,
                          ),
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
  }
}

/// "Apple ile Giriş" düğmesi — yalnız Apple platformlarında çizilir.
///
/// App Store İnceleme Kılavuzu 4.8, üçüncü taraf sosyal giriş (Google)
/// sunan uygulamalarda eşdeğer bir Apple seçeneğini zorunlu kılar; bu
/// düğme olmadan uygulama incelemeden geçemiyordu (2026-07-25 denetimi).
/// Görsel stil Apple'ın marka kuralına uyar: siyah zemin, beyaz logo ve
/// metin, Google düğmesiyle aynı yükseklik.
class _AppleSignInButton extends StatelessWidget {
  const _AppleSignInButton({required this.onPressed, this.dense = false});

  final VoidCallback? onPressed;
  final bool dense;

  /// Düğme yalnız iOS/macOS'ta anlamlıdır; diğer platformlarda kural da
  /// geçerli değildir ve gereksiz bir seçenek eklemek istemiyoruz.
  static bool get isSupportedPlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return IgnorePointer(
      ignoring: !enabled,
      child: Opacity(
        opacity: enabled ? 1 : 0.55,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              onTap: onPressed,
              child: Container(
                height: dense ? 48 : 54,
                padding: EdgeInsets.symmetric(horizontal: dense ? 12 : 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.apple,
                      color: Colors.white,
                      size: dense ? 20 : 24,
                    ),
                    SizedBox(width: dense ? 8 : 12),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          context.t(K.signInApple),
                          maxLines: 1,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: dense ? 14 : 16,
                            letterSpacing: 0.1,
                          ),
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
  }
}

/// Misafir girişi: ikincil eylem olarak altı çizili metin bağlantısı.
/// (Tek baskın CTA Google butonudur; bu, üçüncü tam boy butonu kaldırır.)
class _GuestSignInLink extends StatelessWidget {
  const _GuestSignInLink({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final isLight = AppTheme.isLight(context);
    final fg = isLight ? AppTheme.lightTextPrimary : Colors.white;
    return IgnorePointer(
      ignoring: !enabled,
      child: Opacity(
        opacity: enabled ? 1 : 0.55,
        // Misafir girişi bir *kaçış yolu*, üçüncü bir teklif değil. Turuncu
        // konturlu tam boy buton olarak Google (beyaz) ve Apple (siyah)
        // düğmeleriyle aynı ağırlıktaydı; ekranda üç birincil eylem
        // görünüyor ve hangisinin beklenen yol olduğu belirsiz kalıyordu
        // (2026-07-25 canlı denetimi). Metin bağlantısı hiyerarşiyi
        // netleştirir, eylemi kaldırmadan.
        child: TextButton.icon(
          onPressed: onPressed,
          icon: Icon(AppIcons.user, size: 17, color: fg.withValues(alpha: 0.8)),
          label: Text(
            context.t(K.continueGuest),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: fg.withValues(alpha: 0.85),
              decoration: TextDecoration.underline,
              decorationColor: fg.withValues(alpha: 0.4),
            ),
          ),
          style: TextButton.styleFrom(
            foregroundColor: fg,
            // Dokunma hedefi iOS asgarisinin (44pt) altına inmez.
            minimumSize: const Size(double.infinity, 46),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            // `styleFrom(textStyle:)` temanın biçimini değiştirir,
            // birleştirmez; aile yazılmazsa yazı sistem tipine düşer.
            textStyle: const TextStyle(
              fontFamily: AppTypography.fontFamily,
              fontWeight: FontWeight.w600,
              fontSize: 14,
              letterSpacing: 0.1,
            ),
          ),
        ),
      ),
    );
  }
}

/// E-posta giriş formunun üstündeki statik bölüm ayıracı (çizgi + metin).
/// Form her zaman açık gösterildiği için aç/kapa chevron'u yoktur.
class _EmailSectionDivider extends StatelessWidget {
  const _EmailSectionDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 44),
      alignment: Alignment.center,
      child: Row(
        children: [
          Expanded(
            child: Divider(color: AppTheme.borderColor(context), thickness: 1),
          ),
          Flexible(
            // Uzun çeviri metni iki Expanded çizgiyle eşit pay (flex:1)
            // aldığında dar ekranlarda kesiliyordu; metne 3 kat pay
            // veriyoruz ki çizgiler ince kalıp metin tam sığsın.
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                context.t(K.orWithEmail),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.caption.copyWith(
                  color: AppTheme.textMutedColor(context),
                ),
              ),
            ),
          ),
          Expanded(
            child: Divider(color: AppTheme.borderColor(context), thickness: 1),
          ),
        ],
      ),
    );
  }
}

class _AuthScrollFrame extends StatelessWidget {
  const _AuthScrollFrame({required this.builder});

  // isWide gerçek yerleşim genişliğinden hesaplanır (MediaQuery.size değil):
  // bölünmüş ekran/katlanabilir cihaz ve testlerde doğru düzen seçilir.
  final Widget Function(BuildContext context, bool isWide) builder;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 720;
        const edgePadding = 32.0;
        // 2026-07-22 canlı UX denetimi: dikey ortalama + padding düzeltmesi
        // minHeight clamp: klavye açıldığında negatif değer engellenir
        return SingleChildScrollView(
          padding: const EdgeInsets.all(edgePadding),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isWide ? 960 : 420,
              minHeight: (constraints.maxHeight - (edgePadding * 2)).clamp(
                0.0,
                double.infinity,
              ),
            ),
            child: Center(child: builder(context, isWide)),
          ),
        );
      },
    );
  }
}

class _LanguageToggle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isKu = context.isKu;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppTheme.surfaceHiColor(context).withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppTheme.borderColor(context).withValues(alpha: 0.3),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
            spreadRadius: -2,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _LanguageChip(
            label: 'KU',
            active: isKu,
            onTap: () => context.langProvider.setLang('ku'),
          ),
          _LanguageChip(
            label: 'TR',
            active: !isKu,
            onTap: () => context.langProvider.setLang('tr'),
          ),
        ],
      ),
    );
  }
}

class _LanguageChip extends StatelessWidget {
  const _LanguageChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Erişilebilirlik ağacında bu iki buton etiketsiz görünüyordu
    // (yalnız "button"); ekran okuyucu hangi dile geçildiğini
    // söyleyemiyordu (2026-07-22 canlı UX denetimi).
    return Semantics(
      button: true,
      selected: active,
      label: label == 'KU' ? 'Kurmancî' : 'Türkçe',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeInOut,
          constraints: const BoxConstraints(minHeight: 36, minWidth: 36),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            gradient: active ? AppTheme.accentGradient : null,
            borderRadius: BorderRadius.circular(20),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: AppTheme.primaryGradientStart.withValues(
                        alpha: 0.35,
                      ),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: AppTypography.bodyMedium.copyWith(
              color: active ? Colors.white : AppTheme.textMutedColor(context),
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }
}
