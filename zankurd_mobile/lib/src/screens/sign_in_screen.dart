import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../animations/load_animations.dart';
import '../l10n/lang.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import '../utils/app_route.dart';
import '../widgets/app_logo.dart';
import '../widgets/geometric_shapes.dart';
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(authProvider.errorMessage!)));
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(authProvider.errorMessage!)));
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(authProvider.errorMessage!)));
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

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).height < 900;
    final logoWidth = compact ? 118.0 : 200.0;
    final topGap = compact ? 0.0 : 16.0;
    final titleGap = compact ? 12.0 : 32.0;
    final formGap = compact ? 16.0 : 40.0;
    final actionGap = compact ? 12.0 : 28.0;
    final altGap = compact ? 8.0 : 20.0;
    final bottomGap = compact ? 14.0 : 32.0;

    return Scaffold(
      body: Stack(
        children: [
          // Dark gradient background
          Container(
            decoration: const BoxDecoration(
              gradient: AppTheme.darkAuthGradient,
            ),
          ),
          // Geometric shape overlays
          Positioned(
            top: -60,
            right: -80,
            child: ScaleTransition(
              scale: LoadAnimationSequence.logoScaleAnimation(
                _animationController,
              ),
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppTheme.accent.withValues(alpha: 0.08),
                      AppTheme.violet.withValues(alpha: 0.04),
                    ],
                  ),
                ),
                child: ClipPath(
                  clipper: OctagonClipper(),
                  child: Container(
                    color: AppTheme.accent.withValues(alpha: 0.05),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            left: -100,
            child: ScaleTransition(
              scale: LoadAnimationSequence.logoScaleAnimation(
                _animationController,
              ),
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomRight,
                    end: Alignment.topLeft,
                    colors: [
                      AppTheme.violet.withValues(alpha: 0.08),
                      AppTheme.accent.withValues(alpha: 0.04),
                    ],
                  ),
                ),
                child: ClipPath(
                  clipper: DiamondClipper(),
                  child: Container(
                    color: AppTheme.violet.withValues(alpha: 0.05),
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
                      SizedBox(height: titleGap),
                      // Title and subtitle with animations
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
                          child: Column(
                            children: [
                              Text(
                                context.s(
                                  'Bi xêr hatî ZanKurdê',
                                  'ZanKurd\'a Hoş Geldin',
                                ),
                                style: const TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 26,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                context.s(
                                  'Kurmancî hîn bibe û pêşbirkê bike',
                                  'Kurmancî öğren ve yarışmaya katıl',
                                ),
                                style: const TextStyle(
                                  color: AppTheme.textSub,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: formGap),
                      // Form fields with fade animations
                      FadeTransition(
                        opacity: LoadAnimationSequence.formField1FadeAnimation(
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
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
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
                                  controller: _passwordController,
                                  obscureText: _obscurePassword,
                                  prefixIcon: Icons.lock_outlined,
                                  suffixIcon: _obscurePassword
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                  onSuffixIconPressed: () {
                                    setState(
                                      () =>
                                          _obscurePassword = !_obscurePassword,
                                    );
                                  },
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
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
                                      : () => _resetPassword(authProvider),
                                  child: Text(
                                    context.s(
                                      'Şîfre ji bîr kir?',
                                      'Parolayı unuttun mu?',
                                    ),
                                    style: const TextStyle(
                                      color: AppTheme.textSub,
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
                        opacity: LoadAnimationSequence.buttonFadeAnimation(
                          _animationController,
                        ),
                        child: ScaleTransition(
                          scale: LoadAnimationSequence.buttonScaleAnimation(
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
                      SizedBox(height: actionGap),
                      // Divider
                      Row(
                        children: [
                          const Expanded(
                            child: Divider(
                              color: AppTheme.border,
                              thickness: 1,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              context.s('AN JÎ', 'VEYA'),
                              style: const TextStyle(
                                color: AppTheme.textMuted,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const Expanded(
                            child: Divider(
                              color: AppTheme.border,
                              thickness: 1,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: altGap),
                      // Google Sign In
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: authProvider.isLoading
                              ? null
                              : () => _signInWithGoogle(authProvider),
                          icon: const Text(
                            'G',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                              color: AppTheme.gold,
                            ),
                          ),
                          label: Text(
                            context.s(
                              'Bi Google têkeve',
                              'Google ile giriş yap',
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Guest Sign In
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: authProvider.isLoading
                              ? null
                              : () => _signInAsGuest(authProvider),
                          icon: const Icon(
                            Icons.person_outline,
                            size: 20,
                            color: AppTheme.textSub,
                          ),
                          label: Text(
                            context.s(
                              'Wek mêvan bidomîne',
                              'Misafir olarak devam et',
                            ),
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
                            context.s('Hesabê te tune? ', 'Hesabın yok mu? '),
                            style: const TextStyle(
                              color: AppTheme.textSub,
                              fontSize: 14,
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
                              style: const TextStyle(
                                color: AppTheme.accent,
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: bottomGap),
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
}

class _AuthScrollFrame extends StatelessWidget {
  const _AuthScrollFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth < 380 ? 16.0 : 24.0;
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            0,
            horizontalPadding,
            24,
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

class _LanguageToggle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isKu = context.isKu;
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: AppTheme.surfaceHi.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.border.withValues(alpha: 0.5),
          width: 1,
        ),
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
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? AppTheme.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : AppTheme.textMuted,
            fontWeight: FontWeight.w900,
            fontSize: 12,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}
