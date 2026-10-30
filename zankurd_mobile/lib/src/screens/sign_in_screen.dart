import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../animations/load_animations.dart';
import '../l10n/lang.dart';
import '../l10n/strings.dart';
import '../providers/auth_provider.dart';
import '../providers/reduced_motion_provider.dart';
import '../services/analytics_service.dart';
import '../utils/app_route.dart';
import '../widgets/app_logo.dart';
import '../widgets/auth_social_buttons.dart';
import '../widgets/consent_line.dart';
import '../widgets/language_toggle.dart';
import '../widgets/loading_overlay.dart';
import '../widgets/sahne/sahne.dart';
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

  /// T4: yalnız e-posta formu açılır; sosyal yollar ilk karede görünür.
  bool _formOpen = false;

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
    // Bu ekranda Form sarmalayıcısı yok; boş alan kontrolü elle yapılır
    // (alanlar satır içi doğrulamayı kendileri gösterir).
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

    if (success) {
      AnalyticsService.instance.logSignIn('email');
    }

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

    // Android/web dış OAuth akışında `true`, oturumun tamamlandığını
    // değil yalnız tarayıcı/redirect akışının başlatıldığını gösterebilir.
    // Login metriğini ancak AuthProvider gerçekten bir session gördüğünde yaz.
    if (success && authProvider.isAuthenticated) {
      AnalyticsService.instance.logSignIn('google');
    }

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

    if (success && authProvider.isAuthenticated) {
      AnalyticsService.instance.logSignIn('apple');
    }

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

    if (success) {
      AnalyticsService.instance.logSignIn('guest');
    }

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
    // Kademeli logo/başlık girişi süsüdür. Tercih açıkken onboarding ve
    // splash gibi ilk karede bitmiş değerde durur; yoksa ayar, kullanıcının
    // gördüğü ilk form ekranında yok sayılmış olur.
    if (ReducedMotionProvider.isReducedIn(context)) {
      _animationController.value = 1;
    }
    final t = SahneTokens.of(context);

    // T4: misafir ve sosyal yollar aynı akışta, yalnız e-posta formu açılır.
    return LayoutBuilder(
      builder: (context, constraints) {
        return Consumer<AuthProvider>(
          builder: (context, authProvider, _) {
            final loading = authProvider.isLoading;

            final form = Form(
              key: _formKey,
              child: FadeTransition(
                opacity: LoadAnimationSequence.formField1FadeAnimation(
                  _animationController,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SahneField(
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      label: context.t(K.emailAddress),
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      prefixIcon: AppIcons.envelope,
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
                    const SizedBox(height: SahneSpace.x3),
                    FadeTransition(
                      opacity: LoadAnimationSequence.formField2FadeAnimation(
                        _animationController,
                      ),
                      child: SahneField(
                        autovalidateMode: AutovalidateMode.onUserInteraction,
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
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: SahneButton.text(
                        label: context.t(K.forgotPassword),
                        arrow: false,
                        onPressed: loading
                            ? null
                            : () => _resetPassword(authProvider),
                      ),
                    ),
                  ],
                ),
              ),
            );

            final panel = SahneSurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  form,
                  const SizedBox(height: SahneSpace.x2),
                  // Form açılınca giriş birincil, misafir yolu ikincildir (T4).
                  SahneButton.primary(
                    key: const ValueKey('sign-in-submit'),
                    label: context.t(K.signIn),
                    icon: AppIcons.rightToBracket,
                    arrow: false,
                    expand: true,
                    onPressed: loading ? null : () => _signIn(authProvider),
                  ),
                ],
              ),
            );

            final socialButtons = AuthSocialButtons(
              onGoogle: loading ? null : () => _signInWithGoogle(authProvider),
              onApple: loading ? null : () => _signInWithApple(authProvider),
            );
            final signUpLink = Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: SahneSpace.x1,
              children: [
                Text(
                  context.t(K.noAccountPrefix),
                  style: SahneType.body.copyWith(color: t.tx2),
                ),
                SahneButton.text(
                  label: context.t(K.signUp),
                  onPressed: loading
                      ? null
                      : () => Navigator.of(
                          context,
                        ).push(AppRoute.to(const SignUpScreen())),
                ),
              ],
            );

            return SahneEntryScaffold(
              leading: const LanguageToggle(
                kuKey: ValueKey('sign-in-language-chip-KU'),
                trKey: ValueKey('sign-in-language-chip-TR'),
              ),
              // Tur 2 R4: ortadaki boşluk dağ + güneş manzarasıyla dolar
              // (ana sayfadaki görev kartının çizimi); logo gökte durur.
              hero: _AnimatedTitle(
                controller: _animationController,
                child: SahneEntryScene(
                  key: const ValueKey('sign-in-hero-banner'),
                  // Kompakt manzara: 375×667 ilk karede tüm giriş yollarına yer.
                  height: 72,
                  child: ScaleTransition(
                    scale: LoadAnimationSequence.logoScaleAnimation(
                      _animationController,
                    ),
                    child: const AppLogo(width: 64),
                  ),
                ),
              ),
              title: context.t(K.welcomeTitle),
              // Tek satır ürün vaadi (tur 2 R4).
              body: context.t(K.entryPromise),
              content: _formOpen
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        socialButtons,
                        const AuthEmailDivider(),
                        panel,
                      ],
                    )
                  : null,
              anchorActions: _formOpen,
              aboveAction: _formOpen ? const ConsentLine() : null,
              primaryFirstWhenFlowing: true,
              primary: FadeTransition(
                opacity: LoadAnimationSequence.buttonFadeAnimation(
                  _animationController,
                ),
                child: ScaleTransition(
                  scale: LoadAnimationSequence.buttonScaleAnimation(
                    _animationController,
                  ),
                  child: _formOpen
                      ? SahneButton.secondary(
                          key: const ValueKey('sign-in-play-now'),
                          label: context.t(K.continueGuest),
                          icon: AppIcons.play,
                          arrow: false,
                          expand: true,
                          onPressed: loading
                              ? null
                              : () => _signInAsGuest(authProvider),
                        )
                      : SahneButton.primary(
                          key: const ValueKey('sign-in-play-now'),
                          label: context.t(K.continueGuest),
                          icon: AppIcons.play,
                          arrow: false,
                          expand: true,
                          onPressed: loading
                              ? null
                              : () => _signInAsGuest(authProvider),
                        ),
                ),
              ),
              secondary: _formOpen
                  ? signUpLink
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: SahneSpace.x1),
                        socialButtons,
                        if (!_formOpen) ...[
                          const SizedBox(height: SahneSpace.x2),
                          SahneButton.secondary(
                            key: const ValueKey('sign-in-have-account'),
                            label: context.t(K.signInEmail),
                            icon: AppIcons.envelope,
                            arrow: false,
                            expand: true,
                            onPressed: loading
                                ? null
                                : () => setState(() => _formOpen = true),
                          ),
                        ],
                        const SizedBox(height: SahneSpace.x2),
                        const ConsentLine(),
                        signUpLink,
                      ],
                    ),
            );
          },
        );
      },
    );
  }
}

/// Başlığın kademeli girişi: solarak ve 20 px aşağıdan gelir. Hareketi
/// azalt açıkken denetleyici ilk karede bitmiş değerdedir.
class _AnimatedTitle extends StatelessWidget {
  const _AnimatedTitle({required this.controller, required this.child});

  final AnimationController controller;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final slide = LoadAnimationSequence.titleSlideAnimation(controller);
    return FadeTransition(
      opacity: LoadAnimationSequence.titleFadeAnimation(controller),
      child: AnimatedBuilder(
        animation: slide,
        builder: (context, child) =>
            Transform.translate(offset: Offset(0, slide.value), child: child),
        child: child,
      ),
    );
  }
}
