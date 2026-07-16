import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../animations/load_animations.dart';
import '../l10n/lang.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import '../utils/app_route.dart';
import '../widgets/app_logo.dart';
import '../widgets/kilim_pattern_painter.dart';
import '../widgets/loading_overlay.dart';
import '../widgets/styled_button.dart';
import '../widgets/styled_input.dart';
import 'sign_up_screen.dart';

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
      duration: const Duration(milliseconds: 2000),
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
      _showAuthError(context.s('E-peyam pêwîst e', 'E-posta gerekli'));
      return;
    }
    if (_passwordController.text.isEmpty) {
      _showAuthError(context.s('Şîfre pêwîst e', 'Parola gerekli'));
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    LoadingOverlay.show(
      context,
      message: context.s('Tê têketin...', 'Giriş yapılıyor...'),
    );

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
    LoadingOverlay.show(
      context,
      message: context.s(
        'Bi Google ve tê girêdan...',
        'Google ile bağlanılıyor...',
      ),
    );

    final success = await authProvider.signInWithGoogle();

    if (mounted) {
      LoadingOverlay.hide(context);

      if (!success && authProvider.errorMessage != null) {
        _showAuthError(authProvider.errorMessage!);
      }
    }
  }

  Future<void> _signInAsGuest(AuthProvider authProvider) async {
    LoadingOverlay.show(
      context,
      message: context.s(
        'Wek mêvan tê têketin...',
        'Misafir olarak giriliyor...',
      ),
    );

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
        SnackBar(
          content: Text(
            context.s(
              'Pêşî navnîşana e-peyamê ya derbasdar binivîse.',
              'Önce geçerli e-posta adresini yaz.',
            ),
          ),
        ),
      );
      return;
    }

    LoadingOverlay.show(
      context,
      message: context.s(
        'E-peyama vesazkirinê tê şandin...',
        'Sıfırlama e-postası gönderiliyor...',
      ),
    );

    final success = await authProvider.resetPassword(email);

    if (!mounted) return;
    LoadingOverlay.hide(context);

    final message = success
        ? context.s(
            'Girêdana vesazkirina şîfreyê ji e-peyama te re hat şandin.',
            'Parola sıfırlama bağlantısı e-postana gönderildi.',
          )
        : authProvider.errorMessage ??
              context.s(
                'Vesazkirina şîfreyê bi ser neket.',
                'Parola sıfırlama başarısız.',
              );
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  bool _isValidEmail(String value) {
    return value.contains('@') && value.contains('.');
  }

  void _showAuthError(String message) {
    final localized =
        message == 'Bağlantı kurulamadı. İnternet/DNS erişimini kontrol et.'
        ? context.s('Girêdan çênebû. Înternet an DNS kontrol bike.', message)
        : message;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(localized), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final compact = screenSize.height < 900;
    final logoWidth = compact ? 118.0 : 200.0;
    final topGap = compact ? 0.0 : AppSpacing.md;
    final actionGap = compact ? AppSpacing.sm : AppSpacing.lg;
    final altGap = compact ? 8.0 : 20.0;
    final bottomGap = compact ? 14.0 : 32.0;
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

    return Scaffold(
      body: Stack(
        children: [
          // Context-aware düz zemin (light: lightBg, dark: bg)
          Container(decoration: BoxDecoration(color: AppTheme.bgOf(context))),
          // Soft Glow 1: Sağ Üst
          Positioned(
            top: -120,
            right: -120,
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
          // Soft Glow 2: Sol Alt
          Positioned(
            bottom: -140,
            left: -140,
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
          // Main content
          Positioned.fill(
            child: SafeArea(
              child: _AuthScrollFrame(
                child: Consumer<AuthProvider>(
                  builder: (context, authProvider, _) {
                    final width = screenSize.width;
                    final isWide = width > 720;
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
                                  if (denseWide)
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _GoogleSignInButton(
                                            dense: true,
                                            onPressed: authProvider.isLoading
                                                ? null
                                                : () => _signInWithGoogle(
                                                    authProvider,
                                                  ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: _GuestSignInButton(
                                            dense: true,
                                            onPressed: authProvider.isLoading
                                                ? null
                                                : () => _signInAsGuest(
                                                    authProvider,
                                                  ),
                                          ),
                                        ),
                                      ],
                                    )
                                  else ...[
                                    _GoogleSignInButton(
                                      onPressed: authProvider.isLoading
                                          ? null
                                          : () =>
                                                _signInWithGoogle(authProvider),
                                    ),
                                    SizedBox(height: wideButtonGap),
                                    _GuestSignInButton(
                                      onPressed: authProvider.isLoading
                                          ? null
                                          : () => _signInAsGuest(authProvider),
                                    ),
                                  ],
                                  SizedBox(height: wideButtonGap),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Divider(
                                          color: AppTheme.borderColor(context),
                                          thickness: 1,
                                        ),
                                      ),
                                      Flexible(
                                        // Uzun çeviri metni ("An jî bi
                                        // e-peyamê") iki Expanded çizgiyle eşit
                                        // pay (flex:1) aldığında dar
                                        // ekranlarda kesiliyordu; metne 3 kat
                                        // pay veriyoruz ki çizgiler ince kalıp
                                        // metin tam sığsın.
                                        flex: 3,
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                          ),
                                          child: Text(
                                            context.s(
                                              'An jî bi e-peyamê',
                                              'Veya e-posta ile',
                                            ),
                                            textAlign: TextAlign.center,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: AppTypography.caption.copyWith(
                                              color: AppTheme.textMutedColor(
                                                context,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: Divider(
                                          color: AppTheme.borderColor(context),
                                          thickness: 1,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: wideButtonGap),
                                  FadeTransition(
                                    opacity:
                                        LoadAnimationSequence.formField1FadeAnimation(
                                          _animationController,
                                        ),
                                    child: Form(
                                      key: _formKey,
                                      child: Column(
                                        children: [
                                          StyledInputField(
                                            label: context.s(
                                              'Navnîşana e-peyamê',
                                              'E-posta adresi',
                                            ),
                                            labelStyle: authInputLabelStyle,
                                            inputTextStyle: authInputTextStyle,
                                            controller: _emailController,
                                            keyboardType:
                                                TextInputType.emailAddress,
                                            prefixIcon: Icons.email_outlined,
                                            validator: (value) {
                                              if (value == null ||
                                                  value.isEmpty) {
                                                return context.s(
                                                  'E-peyam pêwîst e',
                                                  'E-posta gerekli',
                                                );
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
                                          SizedBox(height: wideGap),
                                          FadeTransition(
                                            opacity:
                                                LoadAnimationSequence.formField2FadeAnimation(
                                                  _animationController,
                                                ),
                                            child: StyledInputField(
                                              label: context.s(
                                                'Şîfre',
                                                'Parola',
                                              ),
                                              labelStyle: authInputLabelStyle,
                                              inputTextStyle:
                                                  authInputTextStyle,
                                              controller: _passwordController,
                                              obscureText: _obscurePassword,
                                              prefixIcon: Icons.lock_outlined,
                                              suffixIcon: _obscurePassword
                                                  ? Icons.visibility_off
                                                  : Icons.visibility,
                                              onSuffixIconPressed: () {
                                                setState(
                                                  () => _obscurePassword =
                                                      !_obscurePassword,
                                                );
                                              },
                                              validator: (value) {
                                                if (value == null ||
                                                    value.isEmpty) {
                                                  return context.s(
                                                    'Şîfre pêwîst e',
                                                    'Parola gerekli',
                                                  );
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
                                          SizedBox(height: denseWide ? 0 : 8),
                                          Align(
                                            alignment: Alignment.centerRight,
                                            child: TextButton(
                                              onPressed: authProvider.isLoading
                                                  ? null
                                                  : () => _resetPassword(
                                                      authProvider,
                                                    ),
                                              child: Text(
                                                context.s(
                                                  'Şîfre ji bîr kir?',
                                                  'Parolayı unuttun mu?',
                                                ),
                                                style: AppTypography.bodyMedium.copyWith(
                                                  color: AppTheme.textSubColor(
                                                    context,
                                                  ),
                                                  fontSize: 13,
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
                                        label: context.s('Têkeve', 'Giriş Yap'),
                                        icon: Icons.login,
                                        isLoading: authProvider.isLoading,
                                        onPressed: authProvider.isLoading
                                            ? null
                                            : () => _signIn(authProvider),
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: wideGap),
                                  Wrap(
                                    alignment: WrapAlignment.center,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      Text(
                                        context.s(
                                          'Hesabê te tune? ',
                                          'Hesabın yok mu? ',
                                        ),
                                        style: AppTypography.bodyMedium.copyWith(
                                          color: AppTheme.textSubColor(context),
                                        ),
                                      ),
                                      GestureDetector(
                                        onTap: () {
                                          Navigator.of(context).push(
                                            AppRoute.to(const SignUpScreen()),
                                          );
                                        },
                                        child: Text(
                                          context.s('Tomar bibe', 'Kaydol'),
                                          style: AppTypography.bodyMedium.copyWith(
                                            color: AppTheme.accent,
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
                            child: AppLogo(width: logoWidth, onCard: true),
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
                              const SizedBox(height: 12),
                              // Guest Sign In
                              _GuestSignInButton(
                                onPressed: authProvider.isLoading
                                    ? null
                                    : () => _signInAsGuest(authProvider),
                              ),
                              SizedBox(height: actionGap),
                              // Divider
                              Row(
                                children: [
                                  Expanded(
                                    child: Divider(
                                      color: AppTheme.borderColor(context),
                                      thickness: 1,
                                    ),
                                  ),
                                  Flexible(
                                    // Uzun çeviri metni iki Expanded çizgiyle
                                    // eşit pay (flex:1) aldığında dar ekranlarda
                                    // kesiliyordu; metne 3 kat pay veriyoruz ki
                                    // çizgiler ince kalıp metin tam sığsın.
                                    flex: 3,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                      ),
                                      child: Text(
                                        context.s(
                                          'An jî bi e-peyamê',
                                          'Veya e-posta ile',
                                        ),
                                        textAlign: TextAlign.center,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTypography.caption.copyWith(
                                          color: AppTheme.textMutedColor(
                                            context,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Divider(
                                      color: AppTheme.borderColor(context),
                                      thickness: 1,
                                    ),
                                  ),
                                ],
                              ),
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
                                    children: [
                                      StyledInputField(
                                        label: context.s(
                                          'Navnîşana e-peyamê',
                                          'E-posta adresi',
                                        ),
                                        labelStyle: authInputLabelStyle,
                                        inputTextStyle: authInputTextStyle,
                                        controller: _emailController,
                                        keyboardType:
                                            TextInputType.emailAddress,
                                        prefixIcon: Icons.email_outlined,
                                        validator: (value) {
                                          if (value == null || value.isEmpty) {
                                            return context.s(
                                              'E-peyam pêwîst e',
                                              'E-posta gerekli',
                                            );
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
                                        opacity:
                                            LoadAnimationSequence.formField2FadeAnimation(
                                              _animationController,
                                            ),
                                        child: StyledInputField(
                                          label: context.s('Şîfre', 'Parola'),
                                          labelStyle: authInputLabelStyle,
                                          inputTextStyle: authInputTextStyle,
                                          controller: _passwordController,
                                          obscureText: _obscurePassword,
                                          prefixIcon: Icons.lock_outlined,
                                          suffixIcon: _obscurePassword
                                              ? Icons.visibility_off
                                              : Icons.visibility,
                                          onSuffixIconPressed: () {
                                            setState(
                                              () => _obscurePassword =
                                                  !_obscurePassword,
                                            );
                                          },
                                          validator: (value) {
                                            if (value == null ||
                                                value.isEmpty) {
                                              return context.s(
                                                'Şîfre pêwîst e',
                                                'Parola gerekli',
                                              );
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
                                      const SizedBox(height: 12),
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: TextButton(
                                          onPressed: authProvider.isLoading
                                              ? null
                                              : () => _resetPassword(
                                                  authProvider,
                                                ),
                                          child: Text(
                                            context.s(
                                              'Şîfre ji bîr kir?',
                                              'Parolayı unuttun mu?',
                                            ),
                                            style: TextStyle(
                                              color: AppTheme.textSubColor(
                                                context,
                                              ),
                                              fontSize: 13,
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
                                    label: context.s('Têkeve', 'Giriş Yap'),
                                    icon: Icons.login,
                                    isLoading: authProvider.isLoading,
                                    onPressed: authProvider.isLoading
                                        ? null
                                        : () => _signIn(authProvider),
                                  ),
                                ),
                              ),
                              SizedBox(height: compact ? 16 : 24),
                              // Sign Up link
                              Wrap(
                                alignment: WrapAlignment.center,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    context.s(
                                      'Hesabê te tune? ',
                                      'Hesabın yok mu? ',
                                    ),
                                    style: AppTypography.bodyMedium.copyWith(
                                      color: AppTheme.textSubColor(context),
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () {
                                      Navigator.of(
                                        context,
                                      ).push(AppRoute.to(const SignUpScreen()));
                                    },
                                    child: Text(
                                      context.s('Tomar bibe', 'Kaydol'),
                                      style: AppTypography.bodyMedium.copyWith(
                                        color: AppTheme.accent,
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
          // Pirs-inspired yeşil→turuncu compact welcome banner.
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppTheme.playGreen, AppTheme.brandOrangeWarm],
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
                  context.s('Bi xêr hatî ZanKurdê', 'ZanKurd\'a Hoş Geldin'),
                  style: AppTypography.heading1.copyWith(
                    color: Colors.white,
                    fontSize: compact ? 22 : 26,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  context.s(
                    'Kurmancî hîn bibe û pêşbirkê bike',
                    'Kurmancî öğren ve yarışmaya katıl',
                  ),
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
                          context.s('Bi Google têkeve', 'Google ile giriş yap'),
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

class _GuestSignInButton extends StatelessWidget {
  const _GuestSignInButton({required this.onPressed, this.dense = false});

  final VoidCallback? onPressed;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final isLight = AppTheme.isLight(context);
    return IgnorePointer(
      ignoring: !enabled,
      child: Opacity(
        opacity: enabled ? 1 : 0.55,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: isLight
                ? AppTheme.lightSurface
                : Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: isLight
                  ? AppTheme.lightBorder
                  : Colors.white.withValues(alpha: 0.12),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isLight ? 0.08 : 0.15),
                blurRadius: 20,
                offset: const Offset(0, 8),
                spreadRadius: -4,
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
                    if (!dense) ...[
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: isLight
                              ? AppTheme.brandOrange.withValues(alpha: 0.12)
                              : Colors.white.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.person_rounded,
                          color: isLight ? AppTheme.brandOrange : Colors.white,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          context.s(
                            'Wek mêvan bidomîne',
                            'Misafir olarak devam et',
                          ),
                          maxLines: 1,
                          style: TextStyle(
                            color: isLight
                                ? AppTheme.lightTextPrimary
                                : Colors.white,
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

class _AuthScrollFrame extends StatelessWidget {
  const _AuthScrollFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 720;
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
              constraints: BoxConstraints(maxWidth: isWide ? 960 : 420),
              child: child,
            ),
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
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
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
          style: AppTypography.caption.copyWith(
            color: active ? Colors.white : AppTheme.textMutedColor(context),
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}
