import 'package:flutter/material.dart';
import '../theme/brand_icons.dart';
import 'package:provider/provider.dart';

import '../animations/load_animations.dart';
import '../l10n/lang.dart';
import '../l10n/strings.dart';
import '../providers/auth_provider.dart';
import '../providers/reduced_motion_provider.dart';
import '../services/analytics_service.dart';
import '../utils/app_route.dart';
import '../widgets/app_logo.dart';
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

    // 2026-10-01 giriş iskeleti: dil seçici solda, kahraman kart (logo),
    // sola yaslı başlık, tek yüzey kartında sosyal girişler + e-posta formu;
    // ekranın TEK birincil eylemi "Giriş Yap" alt perdede sabit, "Kaydol"
    // altında ikincil metin eylemi (bkz. [SahneEntryScaffold]). Eskiden
    // "Giriş Yap" kartın ortasında kayıyor, dil seçici sağ üstte duruyor,
    // başlık kahraman kartın İÇİNDE ortalanıyordu — kayıt ve ad ekranı başka
    // bir yerleşimdi.
    return LayoutBuilder(
      builder: (context, constraints) {
        // Ölçü kısıttan okunur (`MediaQuery.size` bölünmüş ekranda ve
        // testlerde gerçek alanı söylemez). Kısa yatay telefonda düğmeler bir
        // basamak alçalır (iki sütun, alan dar); dikey telefonda hiç sıkılaşmaz.
        final size = constraints.biggest;
        final denseWide =
            (size.width > 720 || (size.width >= 640 && size.height < 420)) &&
            (size.height < 520 || size.width > size.height);
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
                    SizedBox(height: denseWide ? SahneSpace.x2 : SahneSpace.x4),
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
                  if (_supportsGoogleSignIn) ...[
                    _GoogleSignInButton(
                      dense: denseWide,
                      onPressed: loading
                          ? null
                          : () => _signInWithGoogle(authProvider),
                    ),
                    SizedBox(height: denseWide ? SahneSpace.x1 : SahneSpace.x2),
                  ],
                  if (_supportsAppleSignIn) ...[
                    _AppleSignInButton(
                      dense: denseWide,
                      onPressed: loading
                          ? null
                          : () => _signInWithApple(authProvider),
                    ),
                    SizedBox(height: denseWide ? SahneSpace.x1 : SahneSpace.x2),
                  ],
                  // Misafir girişi bir kaçış yolu: metin bağlantısı olarak
                  // sosyal girişlerden ayrılır.
                  Center(
                    child: _GuestSignInLink(
                      onPressed: loading
                          ? null
                          : () => _signInAsGuest(authProvider),
                    ),
                  ),
                  SizedBox(height: denseWide ? SahneSpace.x1 : SahneSpace.x2),
                  const _EmailSectionDivider(),
                  SizedBox(height: denseWide ? SahneSpace.x1 : SahneSpace.x3),
                  form,
                ],
              ),
            );

            return SahneEntryScaffold(
              leading: const LanguageToggle(
                kuKey: ValueKey('sign-in-language-chip-KU'),
                trKey: ValueKey('sign-in-language-chip-TR'),
              ),
              hero: _AnimatedTitle(
                controller: _animationController,
                child: SahneEntryHero(
                  key: const ValueKey('sign-in-hero-banner'),
                  padding: const EdgeInsets.fromLTRB(
                    SahneSpace.x4,
                    SahneSpace.x6,
                    SahneSpace.x4,
                    SahneSpace.x5,
                  ),
                  child: Center(
                    child: ScaleTransition(
                      scale: LoadAnimationSequence.logoScaleAnimation(
                        _animationController,
                      ),
                      child: const AppLogo(width: 64),
                    ),
                  ),
                ),
              ),
              title: context.t(K.welcomeTitle),
              content: panel,
              primary: FadeTransition(
                opacity: LoadAnimationSequence.buttonFadeAnimation(
                  _animationController,
                ),
                child: ScaleTransition(
                  scale: LoadAnimationSequence.buttonScaleAnimation(
                    _animationController,
                  ),
                  child: SahneButton.primary(
                    label: context.t(K.signIn),
                    icon: AppIcons.rightToBracket,
                    arrow: false,
                    expand: true,
                    onPressed: loading ? null : () => _signIn(authProvider),
                  ),
                ),
              ),
              secondary: Wrap(
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
                    onPressed: () => Navigator.of(
                      context,
                    ).push(AppRoute.to(const SignUpScreen())),
                  ),
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

// Supabase OAuth, iOS'ta da sistem tarayıcısını açıp Info.plist'teki
// `com.zankurd.app://login-callback/` şemasına döner. Bu yüzden sosyal
// girişleri iOS'ta gizlemek hem Google'ı hem de zorunlu Apple seçeneğini
// kaldırıyordu; desteklenen tüm ZanKurd yüzeylerinde gösterilir.
bool get _supportsGoogleSignIn => true;

bool get _supportsAppleSignIn => true;

/// Google'ın kendi marka kılavuzundaki "Sign in with Google" renkleri:
/// beyaz dolgu, #747775 kontur, #1F1F1F yazı. Bunlar Şahnê paletinin
/// değil, üçüncü tarafın zorunlu kimliğidir; bu yüzden belirteç değil,
/// burada adlandırılmış sabittir. Şekil uygulamanın M pahıdır, gölge yok.
const _googleSurface = Color(0xFFFFFFFF);
const _googleStroke = Color(0xFF747775);
const _googleInk = Color(0xFF1F1F1F);

class _GoogleSignInButton extends StatelessWidget {
  const _GoogleSignInButton({required this.onPressed, this.dense = false});

  final VoidCallback? onPressed;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final shape = SahneShape.withSide(SahneShape.m, _googleStroke, width: 1);
    return IgnorePointer(
      ignoring: !enabled,
      child: Opacity(
        // Marka düğmesi Şahnê'nin pasif tonuna boyanamaz (kılavuz); yükleme
        // sürerken yalnız soluklaşır, dokunuş almaz.
        opacity: enabled ? 1 : 0.55,
        child: Material(
          color: _googleSurface,
          shape: shape,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            customBorder: shape,
            onTap: onPressed,
            child: SizedBox(
              height: dense ? 48 : 52,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: dense ? SahneSpace.x3 : SahneSpace.x5,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    BrandIcon(
                      BrandIcons.google,
                      color: _googleInk,
                      size: dense ? 18 : 20,
                    ),
                    SizedBox(width: dense ? SahneSpace.x2 : SahneSpace.x3),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          context.t(K.signInGoogle),
                          maxLines: 1,
                          style: SahneType.button.copyWith(color: _googleInk),
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

class _AppleSignInButton extends StatelessWidget {
  const _AppleSignInButton({required this.onPressed, this.dense = false});

  final VoidCallback? onPressed;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    // Apple'ın kendi düğme kılavuzu iki varyant tanımlar: açık zeminde siyah,
    // koyu zeminde beyaz. Düğme ilk yazıldığında yalnız siyah varyant vardı
    // ve karanlık temada gövde kartın zeminine 1.24:1 ile oturuyordu —
    // yalnız beyaz yazı havada duruyordu (2026-08-16 ekran turu,
    // 75_sign_in_dark). Siyah/beyaz Apple'ın zorunlu kimliğidir, belirteç
    // değil; şekil uygulamanın M pahı, gölge yok.
    final dark = Theme.of(context).brightness == Brightness.dark;
    final surface = dark ? Colors.white : Colors.black;
    final onSurface = dark ? Colors.black : Colors.white;
    return IgnorePointer(
      ignoring: !enabled,
      child: Opacity(
        opacity: enabled ? 1 : 0.55,
        child: AnimatedContainer(
          duration: sahneMotionReduced(context)
              ? Duration.zero
              : SahneMotion.fade,
          decoration: ShapeDecoration(color: surface, shape: SahneShape.m),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              customBorder: SahneShape.m,
              onTap: onPressed,
              child: SizedBox(
                height: dense ? 48 : 52,
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: dense ? SahneSpace.x3 : SahneSpace.x5,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      BrandIcon(
                        BrandIcons.apple,
                        color: onSurface,
                        size: dense ? 18 : 20,
                      ),
                      SizedBox(width: dense ? SahneSpace.x2 : SahneSpace.x3),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: AlignmentDirectional.centerStart,
                          child: Text(
                            context.t(K.signInApple),
                            maxLines: 1,
                            style: SahneType.button.copyWith(color: onSurface),
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
      ),
    );
  }
}

/// Misafir girişi: ikincil eylem olarak altı çizili metin bağlantısı.
/// Sosyal giriş bulunmayan Apple platformlarında da ana akış açık kalır.
///
/// Misafir girişi bir *kaçış yolu*, üçüncü bir teklif değil. Turuncu
/// konturlu tam boy buton olarak Google (beyaz) ve Apple (siyah)
/// düğmeleriyle aynı ağırlıktaydı; ekranda üç birincil eylem görünüyor ve
/// hangisinin beklenen yol olduğu belirsiz kalıyordu (2026-07-25 canlı
/// denetimi). 2026-09-29 Şahnê: birincil metin rengi (Agir değil — Agir
/// ekranın tek birincil eylemine, "Giriş Yap"a ait), 48 dokunma alanı.
class _GuestSignInLink extends StatelessWidget {
  const _GuestSignInLink({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    final enabled = onPressed != null;
    final fg = enabled ? t.tx : t.tx3;
    return IgnorePointer(
      ignoring: !enabled,
      child: TextButton.icon(
        onPressed: onPressed,
        icon: Icon(AppIcons.user, size: 18, color: fg),
        label: Text(
          context.t(K.continueGuest),
          textAlign: TextAlign.center,
          style: SahneType.captionStrong.copyWith(
            color: fg,
            decoration: TextDecoration.underline,
            decorationColor: fg,
          ),
        ),
        style: TextButton.styleFrom(
          foregroundColor: fg,
          minimumSize: const Size(48, 48),
          shape: SahneShape.m,
          padding: const EdgeInsets.symmetric(horizontal: SahneSpace.x4),
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
    final t = SahneTokens.of(context);
    Widget line() => Expanded(
      child: SizedBox(height: 1, child: ColoredBox(color: t.line)),
    );
    return ConstrainedBox(
      // a11y-tap-target: noninteractive — statik bölüm ayıracı.
      constraints: const BoxConstraints(minHeight: 44),
      child: Row(
        children: [
          line(),
          Flexible(
            // Uzun çeviri metni iki Expanded çizgiyle eşit pay (flex:1)
            // aldığında dar ekranlarda kesiliyordu; metne 3 kat pay
            // veriyoruz ki çizgiler ince kalıp metin tam sığsın.
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: SahneSpace.x2),
              child: Text(
                context.t(K.orWithEmail),
                textAlign: TextAlign.center,
                style: SahneType.caption.copyWith(color: t.tx2),
              ),
            ),
          ),
          line(),
        ],
      ),
    );
  }
}
