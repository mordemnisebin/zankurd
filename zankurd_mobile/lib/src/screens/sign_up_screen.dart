import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../animations/load_animations.dart';
import '../l10n/lang.dart';
import '../l10n/strings.dart';
import '../providers/auth_provider.dart';
import '../providers/reduced_motion_provider.dart';
import '../services/analytics_service.dart';
import '../services/display_name_policy.dart';
import '../widgets/loading_overlay.dart';
import '../widgets/sahne/sahne.dart';
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
    // Kademeli adım/başlık girişi süsüdür. Tercih açıkken splash ve giriş
    // gibi ilk karede bitmiş değerde durur; yoksa ayar, kullanıcının
    // gördüğü kayıt sihirbazında yok sayılmış olur.
    if (ReducedMotionProvider.isReducedIn(context)) {
      _animationController.value = 1;
    }
    final t = SahneTokens.of(context);
    final slide = LoadAnimationSequence.titleSlideAnimation(
      _animationController,
    );

    // 2026-09-29 Şahnê: giriş ekranıyla aynı marka anı — gece sahne
    // kartında 28'lik başlık ve adımın açıklaması; üstünde elmas adım
    // göstergesi. Form tek yüzey kartında; "İleri / Hesap oluştur" ekranın
    // tek birincil eylemi, "Geri" ikincil.
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: _AuthScrollFrame(
          child: Consumer<AuthProvider>(
            builder: (context, authProvider, _) {
              final loading = authProvider.isLoading;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ScaleTransition(
                    scale: LoadAnimationSequence.logoScaleAnimation(
                      _animationController,
                    ),
                    child: _ProgressIndicator(currentStep: _currentStep),
                  ),
                  const SizedBox(height: SahneSpace.x4),
                  FadeTransition(
                    opacity: LoadAnimationSequence.titleFadeAnimation(
                      _animationController,
                    ),
                    child: AnimatedBuilder(
                      animation: slide,
                      builder: (context, child) => Transform.translate(
                        offset: Offset(0, slide.value),
                        child: child,
                      ),
                      child: _SignUpHeroBanner(
                        subtitle: _getStepSubtitle(context),
                      ),
                    ),
                  ),
                  const SizedBox(height: SahneSpace.x4),
                  SahneSurfaceCard(
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
                        const SizedBox(height: SahneSpace.x6),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // İlk adımda da geri çıkış olmalı: sihirbazın
                            // hiçbir adımında app bar/geri yoktu, tek
                            // çıkış alttaki metin bağlantısıydı
                            // (2026-07-22 canlı UX denetimi).
                            Expanded(
                              child: SahneButton.secondary(
                                key: const ValueKey('signup-back-button'),
                                label: context.t(K.backStep),
                                expand: true,
                                onPressed: loading
                                    ? null
                                    : (_currentStep > 0
                                          ? _previousStep
                                          : () => Navigator.of(
                                              context,
                                            ).maybePop()),
                              ),
                            ),
                            const SizedBox(width: SahneSpace.x3),
                            Expanded(
                              child: SahneButton.primary(
                                label: _currentStep == 2
                                    ? context.t(K.createAccount)
                                    : context.t(K.nextStep),
                                icon: _currentStep == 2
                                    ? AppIcons.circleCheck
                                    : null,
                                arrow: _currentStep != 2,
                                expand: true,
                                onPressed: loading
                                    ? null
                                    : (_currentStep == 2
                                          ? () => _signUp(authProvider)
                                          : _nextStep),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: SahneSpace.x4),
                        Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: SahneSpace.x1,
                          children: [
                            Text(
                              context.t(K.haveAccountPrefix),
                              style: SahneType.body.copyWith(color: t.tx2),
                            ),
                            _TextAction(
                              label: context.t(K.signIn),
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
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
                // Kayıt burada YALNIZ boşluk/uzunluğa bakıyordu —
                // `DisplayNamePolicy` (isim kapısı ve ayarlarda zaten
                // zorunlu) hiç çağrılmıyordu. Kayıt formu üçüncü bir
                // yazma yolu: engellenen sözcük/bağlantı/kimlik taklidi
                // içeren bir ad, kapıdan hiç geçmeden doğrudan üretilen
                // profile yazılabiliyordu (2026-08-14 denetimi). Sunucu
                // tetikleyicisi yine de reddeder, ama kullanıcı NİÇİN
                // reddedildiğini görmeden "Hesap oluştur"da tıkanırdı.
                validator: (value) {
                  final verdict = DisplayNamePolicy.review(value ?? '');
                  if (verdict == DisplayNameVerdict.allowed) return null;
                  return context.t(DisplayNamePolicy.messageKeyFor(verdict));
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

/// Kayıt adımları: üç elmas. Geçilen ve etkin adım öğrenme tonunda
/// (Zimrût tonu + Halka 2 Zimrût metni, rakam Zimrût metni), gelecek adım
/// Kulis tonunda ikincil rakamla. Durum yalnız renkle değil, halkayla da
/// ayrışır; ekran okuyucu "Adım n" sırasını rakamdan okur.
class _ProgressIndicator extends StatelessWidget {
  final int currentStep;

  const _ProgressIndicator({required this.currentStep});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _ProgressDiamond(number: 1, isActive: currentStep >= 0),
        const SizedBox(width: SahneSpace.x3),
        _ProgressDiamond(number: 2, isActive: currentStep >= 1),
        const SizedBox(width: SahneSpace.x3),
        _ProgressDiamond(number: 3, isActive: currentStep >= 2),
      ],
    );
  }
}

class _ProgressDiamond extends StatelessWidget {
  final int number;
  final bool isActive;

  const _ProgressDiamond({required this.number, required this.isActive});

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    const size = 44.0;
    return AnimatedContainer(
      key: ValueKey('signup-progress-step-$number'),
      duration: sahneMotionReduced(context)
          ? Duration.zero
          : SahneMotion.answerReveal,
      curve: Curves.easeInOut,
      width: size,
      height: size,
      decoration: ShapeDecoration(
        color: isActive ? t.learnTint : t.s2,
        shape: SahneShape.diamond(
          size,
          side: isActive
              ? BorderSide(
                  color: t.learnTx,
                  width: SahneRing.r2,
                  strokeAlign: BorderSide.strokeAlignInside,
                )
              : BorderSide.none,
        ),
      ),
      child: Center(
        child: Text(
          '$number',
          style: SahneType.button.copyWith(
            color: isActive ? t.learnTx : t.tx2,
            fontFeatures: const [FontFeature.tabularFigures()],
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
    final t = SahneTokens.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: SahneType.captionStrong.copyWith(color: t.tx2)),
        const SizedBox(width: SahneSpace.x2),
        Expanded(
          child: Text(
            value,
            style: SahneType.body.copyWith(color: t.tx),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// Marka anı: gece sahne kartı içinde 28'lik başlık + adımın açıklaması.
class _SignUpHeroBanner extends StatelessWidget {
  const _SignUpHeroBanner({required this.subtitle});

  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return SahneStageCard(
      key: const ValueKey('sign-up-hero-banner'),
      padding: const EdgeInsets.fromLTRB(
        SahneSpace.x4,
        SahneSpace.x6,
        SahneSpace.x4,
        SahneSpace.x5,
      ),
      child: Builder(
        builder: (context) {
          final t = SahneTokens.of(context);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: Text(
                  context.t(K.createYourAccount),
                  style: SahneType.title.copyWith(color: t.tx),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: SahneSpace.x1),
              Text(
                subtitle,
                style: SahneType.body.copyWith(color: t.tx2),
                textAlign: TextAlign.center,
              ),
            ],
          );
        },
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
        // Sayfa kenarı 16; dikeyde 24. İçerik ortalanır; klavye açılınca
        // negatif yükseklik oluşmasın diye alt sınır sıfırda kırpılır.
        const padding = EdgeInsets.symmetric(
          horizontal: SahneSpace.page,
          vertical: SahneSpace.x6,
        );
        return SingleChildScrollView(
          padding: padding,
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 440,
                minHeight: (constraints.maxHeight - padding.vertical).clamp(
                  0.0,
                  double.infinity,
                ),
              ),
              child: Center(child: child),
            ),
          ),
        );
      },
    );
  }
}

/// Metin bağlantısı ([SahneButton.text]) — 48'lik dokunma kutusunda.
///
/// Bileşen görselde 44'tür; uygulamanın erişilebilirlik kılavuzu testi
/// (Android) 48'in altını reddeder. [ZkBackButton] gibi: ekran okuyucu tek
/// bir 48'lik düğme görür, görsel boyut değişmez.
class _TextAction extends StatelessWidget {
  const _TextAction({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      button: true,
      enabled: onPressed != null,
      label: label,
      onTap: onPressed,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            widthFactor: 1,
            heightFactor: 1,
            child: SahneButton.text(label: label, onPressed: onPressed),
          ),
        ),
      ),
    );
  }
}
